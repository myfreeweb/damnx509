# damnx509 [![Unlicense](https://img.shields.io/badge/un-license-green.svg?style=flat)](http://unlicense.org)

A simple CLI for managing a small X.509 Certificate Authority!

- Screw the `openssl` binary, shell scripts, searching your command history for `openssl` invocations, this is just much cleaner.
- damnx509 offers a nice interactive `issue` subcommand that lets you set:
    - the extended usage thing (e.g. some WPA2 EAP-TLS clients absolutely require it to be set to `clientAuth`, now you don't have to worry about that)
    - Subject Alternative Names (the `openssl` binary only sets that *from the openssl config file*, what the hell)
    - the signature algorithm (RSA 2048/4096 and EC)
    - the URI of the CRL
- It also automatically offers default values from the CA (e.g. you want to default to the same country, city and CRL URI, right?)
- And automatically builds a PKCS12 (`.p12`) key+cert bundle (useful for browser client certs and WPA2 EAP-TLS).
- There's also a `revoke` subcommand to update the CRL (don't forget to upload it to the URI mentioned in the certificates).
- DON'T FORGET TO [REMOVE](https://en.wikipedia.org/wiki/Srm_(Unix)) UNENCRYPTED KEYS IF YOU WRITE THEM

You can use damnx509 to manage a personal CA to sign things like:

- Your [home router](https://lede-project.org/start)'s admin interface (LuCI)
- Your home router's [WPA2 EAP-TLS network](http://www.blog.10deam.com/2015/01/08/install-freeradius2-on-a-openwrt-router-for-eap-authentication/)
- Your home NAS's web interface
- Your personal OpenVPN network
- Your home server's HTTPS services
- Client certificates for accessing admin/monitoring/etc. interfaces on your servers
- An [IndieCert](https://indiecert.net/faq) client certificate for [signing in with your domain](https://indieweb.org/Web_sign-in)

## Installation

You need Ruby [older than 2.4 for now](https://github.com/r509/r509/issues/122).

```bash
$ gem install damnx509
```

Run the command to see how to use it.

## Contributing

Please feel free to submit pull requests!

By participating in this project you agree to follow the [Contributor Code of Conduct](http://contributor-covenant.org/version/1/4/).

## License

This is free and unencumbered software released into the public domain.  
For more information, please refer to the `UNLICENSE` file or [unlicense.org](http://unlicense.org).
