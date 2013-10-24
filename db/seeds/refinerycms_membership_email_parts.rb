Refinery::Memberships::MembershipEmailP.new({
  :title => 'email_header',
  :body => '<p>Header</p>'
}).save(:validate => false)
Refinery::Memberships::MembershipEmailP.new({
  :title => 'email_footer',
  :body => '<p>Foter</p>'
}).save(:validate => false)
