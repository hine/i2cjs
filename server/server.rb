#!/usr/bin/env ruby
# coding: utf-8
require 'rubygems'
require 'em-websocket'
require 'json'
#require 'i2c'

MAX_LOG = 1

class MPU6050

  def initialize(path, address = 0x68)
    #@device = I2C.create(path)
    #@address = address
  end

  def get_all
    status = {'Accelerometer_X'=>100, 'Accelerometer_Y'=>200, 'Accelerometer_Z'=>300, 'Gyroscope_X'=>10, 'Gyroscope_Y'=>20, 'Gyroscope_Z'=>30, 'Temperature'=>1}
    return status
  end

end

lasttime = Time.now
sensor = MPU6050.new('/dev/i2c-1')

EM::run do
  @channel = EM::Channel.new
  @logs = Array.new
  @channel.subscribe{|mes|
    @logs.push mes
    @logs.shift if @logs.size > MAX_LOG
  }

  EM::WebSocket.run(:host => "0.0.0.0", :port => 12868) do |ws|
    ws.onopen { |handshake|
      puts "WebSocket connection open"
      @sid = @channel.subscribe {|mes|
        ws.send(mes)
      }
      puts "<#{@sid}> connected!!"
      @logs.each{|mes|
        ws.send(mes)
      }
      #@channel.push("hello <#{@sid}>")

      # Access properties on the EM::WebSocket::Handshake object, e.g.
      # path, query_string, origin, headers

      # Publish message to the client
      if handshake.path == '/'
        ws.send "Hello Client, you connected to #{handshake.path}"
      else
        
      end
    }

    ws.onclose {
      @channel.unsubscribe(@sid)
      #@channel.push("<#{@sid}> disconnected")
      puts "<#{@sid}> disconnected"
    }

    ws.onmessage {|mes|
      puts "<#{@sid}> #{mes}"
      #@channel.push("<#{@sid}> #{mes}")
    }
  end

  EM::defer do
    loop do
      elapsedtime = Time.now - lasttime
      lasttime = Time.now
      result = {'currentFrameRate'=> 1 / elapsedtime}
      @channel.push (result.merge(sensor.get_all)).to_json
      sleep 0.01*rand(20)
    end
  end
end
