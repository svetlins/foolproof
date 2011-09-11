#!/usr/bin/env ruby

$LOAD_PATH.unshift(
  File.join(Dir.pwd, '.git', 'hooks')
)

require 'lib/foolproof'

Foolproof.run

