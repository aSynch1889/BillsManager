# frozen_string_literal: true

# Resolve App Store Connect API authentication for deliver / pilot / snapshot.
#
# Supported inputs (env):
#   APP_STORE_CONNECT_API_KEY_PATH  — absolute/relative path to .p8 or Spaceship JSON key
#   APP_STORE_CONNECT_KEY_ID        — Key ID (also: APP_STORE_CONNECT_API_KEY_ID, ASC_KEY_ID)
#   APP_STORE_CONNECT_ISSUER_ID     — Issuer UUID (also: ASC_ISSUER_ID)
#
# Modes:
#   :json     — path ends with .json (or non-.p8 file treated as api_key_path for deliver)
#   :p8       — .p8 + key_id + issuer_id → use app_store_connect_api_key then { api_key: ... }
#   :missing  — incomplete / absent credentials
#
module AppStoreConnectAuth
  module_function

  def first_present(*values)
    values.map { |v| v.to_s.strip }.find { |v| !v.empty? }
  end

  def env_value(env, *keys)
    keys.each do |key|
      value = env[key.to_s]
      return value.to_s.strip unless value.to_s.strip.empty?
    end
    nil
  end

  def expand_path(path, base_dir: nil)
    return nil if path.to_s.strip.empty?

    raw = path.to_s.strip
    expanded = File.expand_path(raw.sub(/\A~/, Dir.home))
    return expanded if File.exist?(expanded)
    return expanded if base_dir.nil?

    alt = File.expand_path(raw, base_dir)
    File.exist?(alt) ? alt : expanded
  end

  # AuthKey_BG9GMFFPV8.p8 → BG9GMFFPV8
  def key_id_from_p8_filename(path)
    base = File.basename(path.to_s, ".*")
    return nil if base.empty?

    if (m = base.match(/\AAuthKey[_-]([A-Z0-9]+)\z/i))
      return m[1]
    end
    if (m = base.match(/\ASubscriptionKey[_-]([A-Z0-9]+)\z/i))
      return m[1]
    end
    # Bare key id filename (10 alnum chars common for Apple keys)
    return base if base.match?(/\A[A-Z0-9]{8,12}\z/i)

    nil
  end

  def p8_file?(path)
    path.to_s.downcase.end_with?(".p8")
  end

  def json_key_file?(path)
    path.to_s.downcase.end_with?(".json")
  end

  # Returns a hash:
  #   status: :ready | :incomplete | :absent
  #   mode:   :json | :p8 | nil
  #   path:, key_id:, issuer_id:
  #   messages: []
  #   deliver_via: :api_key_path | :api_key_object | nil
  def analyze(env = ENV, base_dir: nil)
    path = expand_path(
      env_value(env, "APP_STORE_CONNECT_API_KEY_PATH", "ASC_KEY_PATH", "ASC_API_KEY_PATH"),
      base_dir: base_dir
    )
    key_id = env_value(
      env,
      "APP_STORE_CONNECT_KEY_ID",
      "APP_STORE_CONNECT_API_KEY_ID",
      "ASC_KEY_ID"
    )
    issuer_id = env_value(
      env,
      "APP_STORE_CONNECT_ISSUER_ID",
      "APP_STORE_CONNECT_API_ISSUER_ID",
      "ASC_ISSUER_ID"
    )

    if path.nil?
      return {
        status: :absent,
        mode: nil,
        path: nil,
        key_id: key_id,
        issuer_id: issuer_id,
        deliver_via: nil,
        messages: [
          "APP_STORE_CONNECT_API_KEY_PATH is not set. " \
          "Set path to AuthKey_XXX.p8 (plus KEY_ID + ISSUER_ID) or a JSON API key file."
        ]
      }
    end

    unless File.exist?(path)
      return {
        status: :incomplete,
        mode: nil,
        path: path,
        key_id: key_id,
        issuer_id: issuer_id,
        deliver_via: nil,
        messages: ["API key file not found: #{path}"]
      }
    end

    if p8_file?(path)
      inferred = key_id_from_p8_filename(path)
      key_id = first_present(key_id, inferred)
      messages = []
      messages << "Inferred KEY_ID=#{key_id} from filename #{File.basename(path)}" if inferred && env_value(env, "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_API_KEY_ID", "ASC_KEY_ID").nil?

      missing = []
      missing << "APP_STORE_CONNECT_KEY_ID (or ASC_KEY_ID)" if key_id.to_s.empty?
      missing << "APP_STORE_CONNECT_ISSUER_ID (or ASC_ISSUER_ID)" if issuer_id.to_s.empty?

      if missing.any?
        return {
          status: :incomplete,
          mode: :p8,
          path: path,
          key_id: key_id,
          issuer_id: issuer_id,
          deliver_via: nil,
          messages: messages + [
            "p8 key requires Key ID + Issuer ID. Missing: #{missing.join(', ')}. " \
            "Passing only .p8 to deliver as api_key_path will fail authentication."
          ]
        }
      end

      return {
        status: :ready,
        mode: :p8,
        path: path,
        key_id: key_id,
        issuer_id: issuer_id,
        deliver_via: :api_key_object,
        messages: messages
      }
    end

    # JSON or other prebuilt api key file for Spaceship/deliver
    {
      status: :ready,
      mode: json_key_file?(path) ? :json : :api_key_path,
      path: path,
      key_id: key_id,
      issuer_id: issuer_id,
      deliver_via: :api_key_path,
      messages: []
    }
  end

  def summary_line(analysis)
    case analysis[:status]
    when :ready
      if analysis[:mode] == :p8
        "ASC auth ready (p8): key_id=#{analysis[:key_id]} issuer=#{analysis[:issuer_id]} path=#{analysis[:path]}"
      else
        "ASC auth ready (api_key_path): path=#{analysis[:path]}"
      end
    when :incomplete
      "ASC auth incomplete: #{analysis[:messages].join(' | ')}"
    else
      "ASC auth absent: #{analysis[:messages].join(' | ')}"
    end
  end
end
