# frozen_string_literal: true

module QuestionAnswer
  class VotesController < ::ApplicationController
    before_action :ensure_logged_in
    before_action :find_vote_post
    before_action :ensure_can_see_post
    before_action :ensure_qa_enabled, only: [:create, :destroy]
    before_action :ensure_staff, only: [:set_as_answer]

    def create
      unless Topic.qa_can_vote(@post.topic, current_user)
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_over_limit'
        )
      end

      unless @post.qa_can_vote(current_user.id, vote_params[:direction])
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.one_vote_per_post'
        )
      end

      if QuestionAnswer::VoteManager.vote(@post, current_user, direction: vote_params[:direction])
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def destroy
      if !Topic.qa_votes(@post.topic, current_user).exists?
        raise Discourse::InvalidAccess.new(
          nil,
          nil,
          custom_message: 'vote.error.user_has_not_voted'
        )
      end

      if !QuestionAnswer::VoteManager.can_undo(@post, current_user)
        window = SiteSetting.qa_undo_vote_action_window
        msg = I18n.t('vote.error.undo_vote_action_window', minutes: window)

        render_json_error(msg, status: 403)

        return
      end

      if QuestionAnswer::VoteManager.remove_vote(@post, current_user)
        render json: success_json
      else
        render json: failed_json, status: 422
      end
    end

    def set_as_answer
      Post.transaction do
        @post.update!(reply_to_post_number: nil)
        PostReply.where(reply_post_id: @post.id).delete_all
      end

      render json: success_json
    end

    VOTERS_LIMIT = 20

    def voters
      # TODO: Probably a site setting to hide/show voters
      voters = User
        .joins(:question_answer_votes)
        .where(question_answer_votes: { post_id: @post.id })
        .order("question_answer_votes.created_at DESC")
        .select("users.*", "question_answer_votes.direction")
        .limit(VOTERS_LIMIT)

      render_json_dump(
        voters: serialize_data(voters, BasicVoterSerializer)
      )
    end

    private

    def vote_params
      params.permit(:post_id, :direction)
    end

    def find_vote_post
      if params[:vote].present?
        post_id = vote_params[:post_id]
      else
        params.require(:post_id)
        post_id = params[:post_id]
      end

      @post = Post.find_by(id: post_id)

      raise Discourse::NotFound unless @post
    end

    def ensure_can_see_post
      @guardian.ensure_can_see!(@post)
    end

    def ensure_qa_enabled
      raise Discourse::InvalidAccess.new unless Topic.qa_enabled(@post.topic)
    end
  end
end
