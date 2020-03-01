# name: discourse-mailchimp-webhook
# version: 0.1
# authors: Jay Pfaffman (jay@literatecomputing.com) and Angus McLeod

PLUGIN_NAME = 'discourse_mailchimp_webhook'.freeze

enabled_site_setting :discourse_mailchimp_webhook_enabled


after_initialize do
  register_seedfu_fixtures(Rails.root.join("plugins", "discourse-mailchimp-webhook", "db", "fixtures").to_s)

  load File.expand_path('../serializers/mailchimp_serializer.rb', __FILE__)

  # Temp override method from app/jobs/regular/emit_web_hook_event.rb
  # Pending support for a :after_build_web_hook_header feature or authorization field in the Webhook UI.
  class Jobs::EmitWebHookEvent
    def build_webhook_headers(uri, web_hook_body, web_hook_event)
      content_type =
        case @web_hook.content_type
        when WebHook.content_types['application/x-www-form-urlencoded']
          'application/x-www-form-urlencoded'
        else
          'application/json'
        end

      headers = {
        'Accept' => '*/*',
        'Connection' => 'close',
        'Content-Length' => web_hook_body.bytesize,
        'Content-Type' => content_type,
        'Host' => uri.host,
        'User-Agent' => "Discourse/#{Discourse::VERSION::STRING}",
        'X-Discourse-Instance' => Discourse.base_url,
        'X-Discourse-Event-Id' => web_hook_event.id,
        'X-Discourse-Event-Type' => @arguments[:event_type]
      }

      headers['X-Discourse-Event'] = @arguments[:event_name] if @arguments[:event_name].present?

      # Mailchimp specific header
      headers['Authorization'] = "apikey #{SiteSetting.mailchimp_api_key}"

      if @web_hook.secret.present?
        headers['X-Discourse-Event-Signature'] = "sha256=#{OpenSSL::HMAC.hexdigest("sha256", @web_hook.secret, web_hook_body)}"
      end

      headers
    end
  end

  DiscourseEvent.on(:user_created) do |user|
    # Only proceed if the newsletter option was checked.
    if user.custom_fields[SiteSetting.mailchimp_user_field] == 'true'
      WebHook.enqueue_object_hooks(:user_created, user, 'user_created', MailchimpSerializer)
    end
  end

  Plugin::Filter.register(:after_build_web_hook_body) do |context, body|
    body['user_created'].each do |param, value|
      body[param] = value
    end
    
    body
  end
end
