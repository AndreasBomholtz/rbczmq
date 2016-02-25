# encoding: utf-8

require File.expand_path("../helper.rb", __FILE__)

class TestZmqContext < ZmqTestCase
  def test_context
    ctx = ZMQ::Context.new
    assert_instance_of ZMQ::Context, ctx
    assert_raises(ZMQ::Error) do
      ZMQ::Context.new
    end
    assert_equal ctx, ZMQ.context
  ensure
    ctx.destroy
  end

  def test_destroyed_context
    ctx = ZMQ::Context.new
    ctx.destroy
    assert_raises ZMQ::Error do
      ctx.iothreads = 2
    end
  end

  def test_context_with_iothreads
    ctx = ZMQ::Context.new(2)
    assert_instance_of ZMQ::Context, ctx
    assert_raises(ZMQ::Error) do
      ZMQ::Context.new
    end
    assert_equal ctx, ZMQ.context
  ensure
    ctx.destroy
  end

  def test_iothreads
    ctx = ZMQ::Context.new
    assert_raises TypeError do
      ctx.iothreads = :invalid
    end
    ctx.iothreads = 2
    assert_raises ZMQ::Error do
      ctx.iothreads = -2
    end
  ensure
    ctx.destroy
  end

  def test_linger
    ctx = ZMQ::Context.new
    assert_raises TypeError do
      ctx.linger = :invalid
    end
    ctx.linger = 10
    assert_raises ZMQ::Error do
      ctx.linger = -2
    end
  ensure
    ctx.destroy
  end

  def test_max_sockets
    ctx = ZMQ::Context.new
    assert_raises TypeError do
      ctx.max_sockets = :invalid
    end

    rep = ctx.bind(:REP, "inproc://test.bind_connect")

    ctx.max_sockets = 10
    assert_equal 10, ctx.max_sockets
    ctx.max_sockets = 10240
    assert_equal 10240, ctx.max_sockets
    assert_raises ZMQ::Error do
      ctx.max_sockets = -2
    end
  ensure
    ctx.destroy
  end

  def test_sockets_limits
    ctx = ZMQ::Context.new
    rep = ctx.bind(:REP, "inproc://test.bind_connect")
    p ctx.sockets_limit
    assert_equal 65535, ctx.sockets_limit
  ensure
    ctx.destroy
  end

  def test_bind_connect
    ctx = ZMQ::Context.new
    rep = ctx.bind(:REP, "inproc://test.bind_connect")
    req = ctx.connect(:REQ, "inproc://test.bind_connect")
    req.send('success')
    assert_equal 'success', rep.recv
  ensure
    ctx.destroy
  end

  def test_socket
    ctx = ZMQ::Context.new
    assert_raises TypeError do
      ctx.socket("invalid")
    end
    socket = ctx.socket(ZMQ::REP)
    assert_instance_of ZMQ::Socket::Rep, socket
    assert_nil socket.close
    socket = ctx.socket(:REP)
    assert_instance_of ZMQ::Socket::Rep, socket
    assert_nil socket.close
  ensure
    ctx.destroy
  end
end
