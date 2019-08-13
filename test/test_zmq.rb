# encoding: utf-8

require File.expand_path("../helper.rb", __FILE__)

class TestZmq < ZmqTestCase
  def test_interrupted_p
    assert !ZMQ.interrupted?
  end

  def test_version
    version = ZMQ.version
    assert_instance_of Array, version
    assert version.all?{|v| Integer === v }
  end

  def test_czmq_version
    version = ZMQ.czmq_version
    assert_instance_of Array, version
    assert version.all?{|v| Integer === v }
  end

  def test_now
    assert [Integer].include?(ZMQ.now.class)
  end

  def test_log
    assert_nil ZMQ.log("log message")
  end

  def test_error
    expected = [ZMQ::Error, NilClass]
    assert expected.any?{|c| c === ZMQ.error }
  end

  def test_errno
    assert_instance_of Integer, ZMQ.errno
  end

  def test_select
    ctx = ZMQ::Context.new
    poller = ZMQ::Poller.new
    assert_equal 0, poller.poll
    rep = ctx.socket(:REP)
    rep.linger = 0
    rep.bind("inproc://test.select")
    req = ctx.socket(:REQ)
    req.linger = 0
    req.connect("inproc://test.select")

    r, w, e = ZMQ.select([rep], nil, nil, 1)
    assert_equal [], r
    assert_equal [], w
    assert_equal [], e

    assert req.send("request")

    r, w, e = ZMQ.select([rep], nil, nil, 1)
    assert_equal [rep], r
    assert_equal [], w
    assert_equal [], e
  ensure
    ctx.destroy
  end

  def test_pollitem
    item = ZMQ::Pollitem(STDOUT, ZMQ::POLLIN)
    assert_equal STDOUT, item.pollable
    assert_equal ZMQ::POLLIN, item.events
  end

  def test_resolver
    require 'resolv'
    assert_instance_of Resolv::DNS, ZMQ.resolver
  end
end
