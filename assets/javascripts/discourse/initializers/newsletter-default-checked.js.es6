import { withPluginApi } from 'discourse/lib/plugin-api'

export default {
  name: 'newsletter-default-checked',
  initialize() {
    withPluginApi('0.8.22', api => {
      api.modifyClass('component:user-field', {
        didInsertElement: function() {
          const targetId = Discourse.SiteSettings.mailchimp_user_field.replace('user_field_', '')
          if (this.field.id == targetId) {
            $('.user-field-analystforum-times-weekly input[type="checkbox"]')
              .prop('checked', true)
              .trigger('change');
          }
        }
      })
    })
  }
}
