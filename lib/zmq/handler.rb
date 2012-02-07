# encoding: utf-8

class ZMQ::Handler

  # The ZMQ::Socket or IO instance wrapped by this handler.
  attr_reader :pollable

  # A ZMQ::Socket or IO instance is compulsary on init, with support for optional arguments if a subclasses do require them.
  #
  # pub = ctx.bind(:PUB, "tcp://127.0.0.1:5000") # lower level API
  # item = ZMQ::Pollitem.new(pub)
  # item.handler = ZMQ::Handler.new(pub)
  #
  # class ProducerHandler < ZMQ::Handler
  #   def initialize(pollable, producer)
  #     super
  #     @producer = producer
  #   end
  #
  #   def on_writable
  #     @producer.work
  #   end
  # end
  #
  # ZMQ::Loop.bind(:PUB, "tcp://127.0.0.1:5000", ProducerHandler, producer) # higher level API
  #
  def initialize(pollable, *args)
    # XXX: shouldn't leak into handlers
    unless ZMQ::Socket === pollable || IO === pollable
      raise TypeError.new("#{pollable.inspect} is not a valid ZMQ::Socket instance")
    end
    @pollable = pollable
  end

  # Callback invoked from ZMQ::Loop handlers when the pollable item is ready for reading. Subclasses are expected to implement
  # this contract as the default just raises NotImplementedError. It's reccommended to read in a non-blocking manner
  # from within this callback.
  #
  # def on_readable
  #   msgs << recv
  # end
  #
  def on_readable
    raise NotImplementedError, "ZMQ handlers are expected to implement an #on_readable contract"
  end

  # Callback invoked from ZMQ::Loop handlers when the pollable item is ready for writing. Subclasses are expected to implement
  # this contract as the default just raises NotImplementedError. It's reccommended to write data out as fast as possible
  # from within this callback.
  #
  # def on_writable
  #   send buffer.shift
  # end
  #
  def on_writable
    raise NotImplementedError, "ZMQ handlers are expected to implement an #on_writable contract"
  end

  # Callback for error conditions such as pollable item errors on poll and exceptions raised in callbacks. Receives an exception
  # instance as argument and raises by default.
  #
  # handler.on_error(err)  =>  raise
  #
  def on_error(exception)
    raise exception
  end

  # API that allows handlers to send data regardless of the underlying pollable item type (ZMQ::Socket or IO).
  # XXX: Expose Pollitem#send(data) instead ?
  #
  def send(data)
    case pollable
    when IO
      pollable.write_nonblock(data)
    when ZMQ::Socket
      pollable.send(data)
    end
  end

  # API that allows handlers to receive data regardless of the underlying pollable item type (ZMQ::Socket or IO).
  # XXX: Expose Pollitem#send(data) instead ?
  #
  def recv
    case pollable
    when IO
      # XXX assumed page size
      pollable.read_nonblock(4096)
    when ZMQ::Socket
      pollable.recv_nonblock
    end
  end
end