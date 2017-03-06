require 'thor'
require 'highline'
require 'chronic_duration'
require 'r509'
#require 'damnx509/version'

module Damnx509
  class CLI < Thor
    YAML_FILE = 'damnx509.yaml'
    CAS = 'certificate_authorities'
    CLI = HighLine.new

    desc 'init CA', 'Create a new certificate authority named CA in the current directory'
    def init(name)
      if File.exist?(name)
        puts "#{name} already exists in the current directory."
        return false
      end
      Dir.mkdir(name)
      subject = _ask_subject
      csr = R509::CSR.new(
        type: 'RSA',
        bit_length: 4096,
        subject: subject,
        san_names: _to_san(subject) + _ask_san
      )
      key_filename = "#{name}/root.key.pem"
      _write_with_password(key_filename, csr.key)
      cert_filename = "#{name}/root.cert.pem"
      ext = []
      crl_uri = CLI.ask('CRL URI?')
      ext << R509::Cert::Extensions::CRLDistributionPoints.new(value: [{type: 'URI', value: crl_uri}]) unless crl_uri.empty?
      cert = R509::CertificateAuthority::Signer.selfsign(
        csr: csr,
        extensions: ext,
        not_before: Time.now.to_i,
        not_after: Time.now.to_i + _ask_duration
      )
      File.write(cert_filename, cert.to_pem)
      crl_list_filename = "#{name}/crl.list.txt"
      File.write(crl_list_filename, '')
      crl_number_filename = "#{name}/crl.number.txt"
      File.write(crl_number_filename , '')
      conf = File.exist?(YAML_FILE) ? YAML.load_file(YAML_FILE) : {}
      conf['default_ca'] ||= name
      conf[CAS] ||= {}
      conf[CAS][name] ||= {}
      conf[CAS][name]['ca_cert'] = { 'cert' => cert_filename, 'key' => key_filename }
      conf[CAS][name]['crl_md'] = 'SHA256'
      conf[CAS][name]['crl_validity_hours'] = 24 * 365
      conf[CAS][name]['crl_start_skew_seconds'] = 30
      conf[CAS][name]['crl_list_file'] = crl_list_filename
      conf[CAS][name]['crl_number_file'] = crl_number_filename
      File.write(YAML_FILE, conf.to_yaml)
    end

    desc 'issue NAME [CA]', 'Issue a new certificate (interactively), saving to CA/issued/NAME.* files'
    def issue(name, ca=nil)
      ca ||= ca || _conf['default_ca']
      ca_config = _ca_config(ca)
      if !ca_config
        puts "CA #{ca} not found."
        return false
      end
      subj_defaults = Hash[ca_config.ca_cert.cert.subject.to_a.map { |e| [e[0], e[1]] }]
      ext = []

      ext << R509::Cert::Extensions::BasicConstraints.new(:ca => false)
      CLI.choose do |menu|
        menu.prompt = 'Certificate usage?'
        menu.choice('TLS (HTTPS/SMTPS/IMAPS/OpenVPN/WPA2 EAP-TLS/etc.) Server') {
          ext << R509::Cert::Extensions::ExtendedKeyUsage.new(value: ['serverAuth'])
        }
        menu.choice('TLS (HTTPS/SMTPS/IMAPS/OpenVPN/WPA2 EAP-TLS/etc.) Client') {
          ext << R509::Cert::Extensions::ExtendedKeyUsage.new(value: ['clientAuth'])
        }
        menu.choice('Code Signing') {
          ext << R509::Cert::Extensions::ExtendedKeyUsage.new(value: ['codeSigning'])
        }
        menu.choice('E-mail Protection') {
          ext << R509::Cert::Extensions::ExtendedKeyUsage.new(value: ['emailProtection'])
        }
      end

      cert_type = 'RSA'
      CLI.choose do |menu|
        menu.prompt = 'Signature algorithm?'
        menu.choice('RSA') {}
        menu.choice('EC') { cert_type = 'EC' }
      end
      bit_length = nil
      CLI.choose do |menu|
        menu.prompt = 'Key length?'
        menu.choice('2048') { bit_length = 2048 }
        menu.choice('4096') { bit_length = 4096 }
      end if cert_type == 'RSA'

      crl_ext_p = (ca_config.ca_cert.cert.extensions || []).find { |e| e.oid == 'crlDistributionPoints' }
      crl_uri = CLI.ask('CRL URI?') { |q| q.default = crl_ext_p && crl_ext_p.value.gsub(/\n[^:]+:/, '').strip }
      ext << R509::Cert::Extensions::CRLDistributionPoints.new(value: [{type: 'URI', value: crl_uri}]) unless crl_uri.empty?

      subject = _ask_subject(subj_defaults)
      csr = R509::CSR.new(
        type: cert_type,
        bit_length: bit_length,
        subject: subject,
        san_names: _to_san(subject) + _ask_san
      )
      ext << R509::Cert::Extensions::SubjectAlternativeName.new(value: csr.san)
      Dir.mkdir("#{ca}/issued") unless File.directory?("#{ca}/issued")
      key_filename = "#{ca}/issued/#{name}.key.pem"
      password = _write_with_password(key_filename, csr.key)
      signer = R509::CertificateAuthority::Signer.new(ca_config)
      cert = signer.sign(
        csr: csr,
        extensions: ext,
        not_before: Time.now.to_i,
        not_after: Time.now.to_i + _ask_duration
      )
      cert_filename = "#{ca}/issued/#{name}.cert.pem"
      File.write(cert_filename, cert.to_pem)
      unless password.empty?
        p12_filename = "#{ca}/issued/#{name}.p12"
        cert.write_pkcs12(p12_filename, password, "#{name} cert+key signed by #{ca}")
        puts "Wrote #{cert_filename}, #{key_filename}, #{p12_filename}."
      else
        puts "Wrote #{cert_filename}, #{key_filename}."
      end
    end

    desc 'revoke SERIAL [CA]', 'Revoke a certificate with a given SERIAL'
    def revoke(serial, ca=nil)
      # TODO: revoke from file
      ca ||= ca || _conf['default_ca']
      ca_config = _ca_config(ca)
      if !ca_config
        puts "CA #{ca} not found."
        return false
      end
      admin = R509::CRL::Administrator.new(ca_config)
      ser = serial.gsub(':', '').to_i(16)
      admin.revoke_cert(ser)
      crl = admin.generate_crl
      crl_filename = "#{ca}/crl.pem"
      crl.write_pem(crl_filename)
      puts "Wrote #{crl_filename}."
    end

    private
    def _conf
      @conf ||= YAML.load_file(YAML_FILE)
    end

    def _ca_config(ca_name)
      @ca_config ||= R509::Config::CAConfig.load_from_hash(_conf[CAS][ca_name])
    rescue ArgumentError
      nil
    end

    def _ask_subject(defaults=nil)
      [
        ['C',  CLI.ask('C   - Country (2 letter code):') { |q| q.default = defaults && defaults['C'] }],
        ['ST', CLI.ask('ST  - State or Province (full name):') { |q| q.default = defaults && defaults['ST'] }],
        ['L',  CLI.ask('L   - Locality (e.g. city):') { |q| q.default = defaults && defaults['L'] }],
        ['O',  CLI.ask('O   - Organization (e.g. company):') { |q| q.default = defaults && defaults['O'] }],
        ['OU', CLI.ask('OU  - Organizational Unit (e.g. section):') { |q| q.default = defaults && defaults['OU'] }],
        ['CN', CLI.ask('CN  - Common Name (e.g. fully qualified host name):')]
      ]
    end

    def _ask_san
      result = []
      while cur = CLI.ask("SAN - Subject Alternative Name (enter one; type is automatically recognized, don't write 'DNS' etc.; empty to #{result.empty? ? 'skip' : 'stop'}):")
        break if cur.empty?
        result << cur
      end
      result
    end

    def _to_san(subject)
      [Hash[subject]['CN']]
    end

    def _ask_duration
      ChronicDuration.parse(CLI.ask('Expires in (natural input):') { |q| q.default = '365d'}, keep_zero: true)
    end

    def _ask_password
      CLI.ask('Private key password (empty to skip key encryption):') { |q| q.echo = '*' }
    end

    def _write_with_password(key_filename, key)
      password = _ask_password
      if password.empty?
        key.write_pem(key_filename)
      else
        key.write_encrypted_pem(key_filename, 'aes256', password)
      end
      password
    end
  end
end
