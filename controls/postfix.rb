# frozen_string_literal: true

# copyright: 2015, The Authors
# license: All rights reserved

title 'Postfix section'

postfix_smarthost = input('postfix_smarthost', value: false, description: 'Should postfix use a smarthost')
# postfix_smarthost = true
postfix_smarthost_server = input('postfix_smarthost_server', value: false, description: 'Which smarthost server should be configured')
# postfix_smarthost_server = %( smtp.example.com )
postfix_protocols = input('postfix_protocols', value: '!SSLv2,!SSLv3,!TLSv1,!TLSv1.1', description: 'postfix protocols')
postfix_exclude_ciphers = input('postfix_exclude_ciphers', value: 'aNULL,eNULL,EXP,MD5,IDEA,KRB5,RC2,SEED,SRP', description: 'postfix exclude ciphers')
postfix_master_cf_options = input(
  'postfix_master_cf_options',
  value: [],
  description: 'list of options in /etc/postfix/master.cf'
)
postfix_main_cf_options = input(
  'postfix_main_cf_options',
  value: [
    'inet_interfaces = loopback-only',
    'biff = no',
    'smtpd_helo_required = yes',
    'readme_directory = no',
    'append_dot_mydomain = no',
    'disable_vrfy_command = yes',
    'default_process_limit = 100',
    'smtp_sasl_auth_enable = yes',
    'smtpd_use_tls = yes',
    'smtp_use_tls = yes',
    "smtpd_tls_protocols = #{postfix_protocols}",
    "smtp_tls_exclude_ciphers = #{postfix_exclude_ciphers}",
    'smtp_sasl_security_options = noplaintext,noanonymous',
  ],
  description: 'list of options in /etc/postfix/main.cf'
)

control 'postfix-1.0' do # A unique ID for this control
  impact 0.7 # The criticality, if this control fails.
  title 'postfixd should be present'
  desc 'Ensure postfixd executable and configuration are present'
  describe file('/usr/sbin/postfix') do
    it { should be_file }
    it { should be_executable }
    it { should be_owned_by 'root' }
  end
end

control 'postfix-2.0' do
  impact 0.7
  title 'postfix.conf'
  desc 'Check postfix configuration'
  describe file('/etc/postfix/master.cf') do
    it { should be_file }
    it { should be_owned_by 'root' }
    its('mode') { should cmp '0644' }
    its('content') { should match 'smtp      inet  n       -       y       -       -       smtpd' }
    postfix_master_cf_options.each do |opt|
      its('content') { should match(opt.to_s) }
    end
  end
  describe file('/etc/postfix/main.cf') do
    it { should be_file }
    it { should be_owned_by 'root' }
    its('mode') { should cmp '0644' }
    postfix_main_cf_options.each do |opt|
      its('content') { should match(opt.to_s) }
    end
  end
end

control 'postfix-3.0' do
  impact 0.7
  title 'postfix should be running'
  desc 'Ensure postfix is running'
  only_if { !(virtualization.role == 'guest' && virtualization.system == 'docker') }
  describe processes('master') do
    its('users') { should eq ['root'] }
    its('list.length') { should eq 1 }
  end
  describe processes('qmgr') do
    its('users') { should eq ['postfix'] }
    its('list.length') { should eq 1 }
  end
end

control 'postfix-4.0' do
  impact 0.7
  title 'postfixd should have log files'
  desc 'Ensure postfixd logs file are present'
  if os.redhat?
    describe file('/var/log') do
      it { should be_directory }
      it { should be_owned_by 'root' }
      its('mode') { should cmp '0755' }
    end
    describe file('/var/log/maillog') do
      it { should be_file }
      it { should be_owned_by 'root' }
      its('mode') { should cmp '0600' }
      its('content') { should match 'starting the Postfix mail system' }
      its('content') { should match 'daemon started -- version' }
      its('content') { should_not match 'fatal' }
    end
  else
    ## ubuntu
    describe file('/var/log') do
      it { should be_directory }
      it { should be_owned_by 'root' }
      its('group') { should eq 'syslog' }
      its('mode') { should cmp '0775' }
    end
    describe file('/var/log/mail.log') do
      it { should be_file }
      it { should be_owned_by 'syslog' }
      its('mode') { should match(/0644|0640/) }
      its('content') { should match 'starting the Postfix mail system' }
      its('content') { should match 'daemon started -- version' }
      its('content') { should_not match 'fatal' }
    end
  end
end

if postfix_smarthost
  control 'postfix-5.0' do
    title 'postfix smarthost servers'
    desc 'Ensure smarthost server is configured in defined files'
    postfix_smarthost_server.each do |server|
      describe file('/etc/postfix/smarthost_passwd') do
        it { should be_file }
        its('content') { should match "^[^#]\[#{server}\].*" }
      end
    end
  end
end
