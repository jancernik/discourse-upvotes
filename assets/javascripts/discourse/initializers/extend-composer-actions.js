import I18n from "I18n";
import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import { observes } from "discourse-common/utils/decorators";

export default {
  name: "extend-composer-actions",
  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (!siteSettings.qa_enabled) {
      return;
    }

    withPluginApi("0.13.0", (api) => {
      api.serializeOnCreate("create_as_qa", "createAsQA");

      api.customizeComposerText({
        actionTitle(model) {
          if (model.createAsQA) {
            return I18n.t("composer.create_qa.label");
          } else if (model.topic?.is_qa) {
            return I18n.t("qa.topic.answer.label");
          } else {
            return null;
          }
        },

        saveLabel(model) {
          if (model.createAsQA) {
            return "composer.create_qa.label";
          } else if (model.topic?.is_qa) {
            return "qa.topic.answer.label";
          } else {
            return null;
          }
        },
      });

      api.modifyClass("component:composer-actions", {
        pluginId: "discourse-upvotes",

        toggleQASelected(options, model) {
          model.toggleProperty("createAsQA");
          model.notifyPropertyChange("replyOptions");
          model.notifyPropertyChange("action");
        },
      });

      api.modifySelectKit("composer-actions").appendContent((options) => {
        if (options.action === CREATE_TOPIC) {
          if (options.composerModel.createAsQA) {
            return [
              {
                name: I18n.t("composer.composer_actions.remove_as_qa.label"),
                description: I18n.t(
                  "composer.composer_actions.remove_as_qa.desc"
                ),
                icon: "plus",
                id: "toggleQA",
              },
            ];
          } else {
            return [
              {
                name: I18n.t("composer.composer_actions.create_as_qa.label"),
                description: I18n.t(
                  "composer.composer_actions.create_as_qa.desc"
                ),
                icon: "plus",
                id: "toggleQA",
              },
            ];
          }
        } else {
          return [];
        }
      });

      api.modifyClass("model:composer", {
        pluginId: "discourse-upvotes",

        @observes("categoryId")
        categoryCreateAsQADefault() {
          const createAsQA = this.category?.create_as_qa_default;

          if (this.creatingTopic && createAsQA !== this.createAsQA) {
            this.set("createAsQA", createAsQA);
            this.notifyPropertyChange("replyOptions");
            this.notifyPropertyChange("action");
          }
        },
      });
    });
  },
};
