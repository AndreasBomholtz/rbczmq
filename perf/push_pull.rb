# encoding: utf-8

$:.unshift('.')
require File.join(File.dirname(__FILE__), 'runner')

Runner.start(:push_pull, ENV["MSG_COUNT"], ENV["MSG_SIZE"], ENV["MSG_ENCODING"], ENV["PROCESSES"])
