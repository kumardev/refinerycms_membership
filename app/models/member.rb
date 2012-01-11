class Member < User
  
  def self.per_page
    12
  end
  
  acts_as_indexed :fields => [:first_name, :last_name]
  
  validates :membership_level, :first_name, :last_name, :province, :presence => true
  
  attr_accessible :membership_level, :first_name, :last_name, :title, :organization,
    :street_address, :city, :province, :postal_code, :phone, :fax, :website, 
    :enabled, :add_to_member_until, :role_ids

  set_inheritance_column :membership_level
  
  after_create :set_enabled
  after_create :set_default_roles
  
  def full_name
    "#{self.first_name} #{last_name}"
  end

  def add_to_member_until
    @add_to_member_until || ''
  end
  
  def add_to_member_until=(n)
    @add_to_member_until = n
    add_year_to_member_until n.to_i if n && n.to_i > 0
  end
  
  def email=(e)
    write_attribute(:email, e)
    write_attribute(:username, e)
  end
  
  def enabled=(e)
    write_attribute(:enabled, e)
    e = read_attribute(:enabled)
    e ? ensure_member_role : remove_member_role
    e
  end
  
  def is_member?
    role_ids.include?(Role[:member].id)
  end

  def active_for_authentication?
    a = self.enabled && role_ids.include?(Role[:member].id)
    if RefinerySetting::find_or_set('memberships_timed_accounts', true)
      if member_until.nil?
        a = false
      else
        a = a && member_until.future?
      end
    end
    a
  end
  
  def active?
    active_for_authentication?
  end

  def lapsed?
    if RefinerySetting::find_or_set('memberships_timed_accounts', true)
      if member_until.nil?
        false
      else
        member_until.past?
      end
    else
      false
    end
  end

  # multiple calls extends the membership life
  def activate
    self.is_new = false
    self.enabled = true
    add_year_to_member_until if RefinerySetting::find_or_set('memberships_timed_accounts', true) && member_until.nil?
    ensure_member_role
    save!
  end

  def deactivate
    self.enabled = false
    self.is_new = false
    remove_member_role
    save!
  end
  
  def extend
    self.is_new = false
    self.enabled = true
    nil_paid_until if lapsed? && RefinerySetting::find_or_set('memberships_timed_accounts', true)
    add_year_to_member_until if RefinerySetting::find_or_set('memberships_timed_accounts', true)
    ensure_member_role
    save!
  end
  
  def inactive_message
    self.is_new ? super : I18n.translate('devise.failure.locked')
  end
    
  
  # write_attribute(:is_new, false) if e && self.is_new
  
  
  protected
  
  def set_enabled
    self.enabled = RefinerySetting::find_or_set('memberships_confirmation', 'admin') == 'no'
    save
  end
  
  def set_default_roles
    ids = RefinerySetting::find_or_set('memberships_default_roles', [])
    if ids.present?
      Role::find(:all, :conditions => {'id' => ids}).each do | role |
        self.roles << role
      end
      save
    end
  end

  def add_year_to_member_until(amount = 1)
    if amount && amount > 0
      self.member_until = member_until.nil? || lapsed? ? amount.year.from_now : member_until + amount.year
    end
  end

  def ensure_member_role
    self.add_role(:member) unless has_role?(:member)
  end

  def remove_member_role
    self.roles.delete(Role[:member]) if has_role?(:member)
  end

  def nil_paid_until
    self.member_until = nil
  end
end