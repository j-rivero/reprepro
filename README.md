# reprepro multi

Fork of reprepro to support multi repositories in the same server. The limitation of the original recipe is
that it can be only included once so it is not possible to call it several times for several reprepro.

## Changes from the original fork

* Support for multiple directories in array:
  node['reprepro']['repositories_directories']

* Support for base directory in:
  node.default['reprepro']['base_repo_dir']

* Support for different distributions (only debian/ubuntu)
  node.default['reprepro']['codenames']['debian']
  node.default['reprepro']['codenames']['ubuntu']

## Pending tasks

* Fix the support for Apache. Only work nginx at this moment
* Limitation to support Debian/UBuntu using repo name

