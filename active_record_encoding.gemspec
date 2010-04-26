# Copyright (c) 2009, Michael H. Buselli
# See LICENSE for details.  All other rights reserved.

Gem::Specification.new do |s|
  s.name = 'active_record_encoding'
  s.version = "0.10.1"
  s.summary = "Library to monkey-patch ActiveRecord and add some Unicode awareness"
  s.description = "#{s.summary}\n"
  s.author = "Michael H. Buselli"
  s.email = "cosine@cosine.org"
  s.homepage = "http://cosine.org/"
  #s.files = ["LICENSE"] + Dir.glob('lib/**/*')
  # ruby -e "p ['LICENSE'] + Dir.glob('lib/**/*')"
  s.files = ["LICENSE", "lib/active_record_encoding.rb"]
  s.require_paths = ['lib']
  s.rubyforge_project = "active_record_encoding"
  s.has_rdoc = true
end
