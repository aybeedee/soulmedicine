class Subscription < ApplicationRecord
  extend Memoist

  DAYS = Date::ABBR_DAYNAMES
  HOURS = (0..23).to_a.freeze

  scope :active, -> { where(active: true) }

  belongs_to :user

  enum delivery_method: {
    email: 'email'
  }

  validates :course_slug,
    presence: true,
    uniqueness: { scope: :user_id }

  validates :active, inclusion: [true, false]

  validates :main_language,
    presence: true,
    length: { is: 2 }

  validates :delivery_method, presence: true

  validates :days_utc, presence: true
  validates :hours_utc, presence: true

  validate :validate_course_exists
  validate :validate_languages
  validate :validate_schedule

  default_value_for :delivery_method, 'email'

  def course
    courses_service.get(course_slug) if course_slug.present?
  rescue CoursesService::NotFound
    nil
  end
  memoize :course

  protected

  def validate_course_exists
    errors.add(:base, 'course is not available') if course.blank?
  end

  def validate_languages
    return if course.blank?

    errors.add(:other_languages, 'cannot contain the same langguage as the main language') if other_languages.any? { |l| l == main_language }

    main_allowed = course.enabled_languages.compact
    errors.add(:main_language, "can only be #{main_allowed.to_sentence(last_word_connector: ' or ')}") unless main_allowed.include?(main_language)

    return if other_languages.blank?

    other_allowed = main_allowed - [main_language]
    errors.add(:other_languages, "can only contain #{other_allowed.to_sentence}") if other_languages.any? { |l| !other_allowed.include?(l) }
  end

  def validate_schedule
    errors.add(:days_utc, "can only contain #{DAYS.to_sentence}") if days_utc.any? { |d| !DAYS.include?(d) }

    errors.add(:hours_utc, "can only contain #{HOURS.to_sentence}") if hours_utc.any? { |h| !HOURS.include?(h) }
  end
end
