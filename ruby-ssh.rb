#!/usr/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'optparse'

options = {}
opts = OptionParser.new
opts.on("-h HOSTNAME", "--hostname NAME", String, "Hostname of Server") { |v| @hostname = v }
opts.on("-f Server List", "--file NAME", String, "Server list") { |v| @file = v }
opts.on("--user1 SSH USERNAME", String, "SSH Username of Server") { |v| @username1 = v }
opts.on("--pass1 SSH PASSWORD", String, "SSH Password of Server") { |v| @password1 = v }
opts.on("--user2 SSH USERNAME", String, "SSH Username of Server") { |v| @username2 = v }
opts.on("--pass2 SSH PASSWORD", String, "SSH Password of Server") { |v| @password2 = v }
opts.on("-c SHELL_COMMAND", "--command SHELL_COMMAND", String, "Shell Command to Execute") { |v| @cmd = v }

begin
  opts.parse!(ARGV)
rescue OptionParser::ParseError => e
  puts e
end
raise OptionParser::MissingArgument, "Hostname [-h]" if @hostname.nil? and @file.nil?
raise OptionParser::MissingArgument, "SSH Username [-u]" if @username1.nil?
raise OptionParser::MissingArgument, "SSH Password [-p]" if @password1.nil?
raise OptionParser::MissingArgument, "Command to Execute [-c]" if @cmd.nil?

puts options[:p]

def ssh_sudo(host,username,pass,cmd)
  Net::SSH.start( "#{host}" , "#{username}", :password => "#{pass}", :timeout => 30) do |ssh|
    ssh.open_channel do |channel|
      channel.request_pty do |c, success|
        raise "cloud not request pty" unless success
        c.exec("#{cmd}")
        c.on_data do |c, data|
          if (data [/\[sudo\]|Password/i])
            channel.send_data("#{pass}\n")
            sleep 0.5
          end
          $stdout.print data
        end
        c.on_extended_data do |c, type, data|
          $stderr.print data
        end
        c.on_close { puts "done!" }
      end
      channel.wait
    end
    #channel.wait
  end
end

def ssh(host,username,pass,cmd)
  Net::SSH.start( "#{host}" , "#{username}", :password => "#{pass}", :timeout => 10) do |ssh|
    output = ssh.exec!("#{cmd}")
    puts output
  end
end

def exec(username1,password1,username2,password2,server,cmd)
  begin
    if (cmd [/sudo/])
      ssh_sudo("#{server}","#{username1}","#{password1}","#{cmd}")
    else
      ssh("#{server}","#{username1}","#{password1}","#{cmd}")
    end
  rescue Net::SSH::AuthenticationFailed
    begin
      if (cmd [/sudo/])
        ssh_sudo("#{server}","#{username2}","#{password2}","#{cmd}")
      else
        ssh("#{server}","#{username2}","#{password2}","#{cmd}")
      end
    rescue Net::SSH::AuthenticationFailed
      puts " Auth fail - #{server}"
    end
  rescue Errno::ETIMEDOUT
    puts "  Timed out - #{server}"
  rescue Timeout::Error
    puts "  Timed out - #{server}"
  rescue Errno::EHOSTUNREACH
    puts "  Host unreachable - #{server}"
  rescue (Errno::ECONNREFUSED)
    puts "  Connection refused - #{server}"
  rescue
    puts " Error something!!"
  end
end

###### MAIN ##########
if (@hostname)
  exec(@username1,@password1,@username2,@password2,@hostname,@cmd)
elsif (@file)
  File.open(@file, "r") do |file_handle|
    file_handle.each_line do |server|
      server_ip = server.strip
      puts "================================== START => #{server_ip} ======================================="
      exec(@username1,@password1,@username2,@password2,"#{server}",@cmd)
      puts "=================================== END => #{server_ip} ========================================\n"
    end
  end
end
