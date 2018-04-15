name 'reprepro-multi'
maintainer 'Tim Smith'
maintainer_email 'tsmith@chef.io'
license 'Apache-2.0'
description 'Installs/Configures reprepro for multiples apt repositories'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '0.5.0'

# Doesn't make sense to indicate support for non Debian platforms!
supports 'ubuntu'
supports 'debian'

depends 'build-essential', '>= 3.0'
#depends 'apache2', '>= 3.0'
depends 'chef_nginx', '>= 5.0'
depends 'compat_resource', '>= 12.16'
depends 'gpg'

recipe 'reprepro-multi', 'Installs and configures reprepro for an apt repository'

source_url 'https://github.com/tas50/reprepro'
issues_url 'https://github.com/tas50/reprepro/issues'
chef_version '>= 12.1' if respond_to?(:chef_version)
