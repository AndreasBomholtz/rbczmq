# encoding: utf-8

ctx = ZMQ::Context.new
push = ctx.socket(:PUSH);
push.bind(Runner::ENDPOINT);

msg = Runner.payload

start_time = Time.now
Runner.msg_count.times do
  case Runner.encoding
  when :string
    push.send(msg)
  when :frame
    push.send_frame(ZMQ::Frame(msg))
  when :message
    m =  ZMQ::Message.new
    m.pushstr "header"
    m.pushstr msg
    m.pushstr "body"
    push.send_message(m)
  end
end

puts "Sent #{Runner.msg_count} messages in %ss ..." % (Time.now - start_time)