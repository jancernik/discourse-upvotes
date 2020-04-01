# frozen_string_literal: true

require 'rails_helper'

Fabricator(:comment, from: :post) do
  reply_to_post_number
end

describe QuestionAnswer::TopicExtension do
  fab!(:user)  { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:answers) do
    5.times.map { Fabricate(:post, topic: topic) }.sort_by { |a| a.created_at }
  end
  fab!(:comments) do
    answer_post_nums = answers.map(&:post_number)

    5.times.map do
      Fabricate(
        :comment,
        topic: topic,
        reply_to_post_number: answer_post_nums.sample
      )
    end.sort_by { |c| c.created_at }
  end
  let(:up) { QuestionAnswer::Vote::UP }
  let(:create) { QuestionAnswer::Vote::CREATE }
  let(:destroy) { QuestionAnswer::Vote::DESTROY }
  let(:vote) do
    ->(post, u) do
      QuestionAnswer::Vote.vote(post, u, { direction: up, action: create })
    end
  end

  it 'should return correct comments' do
    comment_ids = comments.map(&:id)
    topic_comment_ids = topic.comments.pluck(:id)

    expect(comment_ids).to eq(topic_comment_ids)
  end

  it 'should return correct answers' do
    answer_ids = answers.map(&:id)
    topic_answer_ids = topic.answers.pluck(:id)

    expect(answer_ids).to eq(topic_answer_ids)
  end

  it 'should return correct answer_count' do
    expect(topic.answers.size).to eq(answers.size)
  end

  it 'should return correct comment_count' do
    expect(topic.comments.size).to eq(comments.size)
  end

  it 'should return correct last_answered_at' do
    expected = answers.last.created_at

    expect(topic.last_answered_at).to eq(expected)
  end

  it 'should return correct last_commented_on' do
    expected = comments.last.created_at

    expect(topic.last_commented_on).to eq(expected)
  end

  it 'should return correct last_answer_post_number' do
    expected = answers.last.post_number

    expect(topic.last_answer_post_number).to eq(expected)
  end

  it 'should return correct last_answerer' do
    expected = answers.last.user.id

    expect(topic.last_answerer.id).to eq(expected)
  end

  context 'ClassMethods' do
    describe '#qa_can_vote' do
      it 'should return false if user is blank' do
        expect(Topic.qa_can_vote(topic, nil)).to eq(false)
      end

      it 'should return false if SiteSetting is disabled' do
        SiteSetting.qa_enabled = false

        expect(Topic.qa_can_vote(topic, user)).to eq(false)
      end

      it 'return false if user has voted and qa_trust_level_vote_limits is false' do
        SiteSetting.qa_trust_level_vote_limits = false
        SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 10)

        post = answers.first

        vote.call(post, user)

        expect(Topic.qa_can_vote(topic, user)).to eq(false)

        SiteSetting.qa_trust_level_vote_limits = true

        expect(Topic.qa_can_vote(topic, user)).to eq(true)
      end

      it 'return false if trust level zero' do
        expect(Topic.qa_can_vote(topic, user)).to eq(true)

        user.trust_level = 0
        user.save!

        expect(Topic.qa_can_vote(topic, user)).to eq(false)
      end

      it 'return false if has voted more than qa_tl*_vote_limit' do
        SiteSetting.qa_trust_level_vote_limits = true

        expect(Topic.qa_can_vote(topic, user)).to eq(true)

        SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 1)

        vote.call(answers[0], user)

        expect(Topic.qa_can_vote(topic, user)).to eq(false)

        SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 2)

        expect(Topic.qa_can_vote(topic, user)).to eq(true)
      end
    end
  end
end
