#!/usr/bin/env ruby
# encoding: utf-8

require 'watir-webdriver'
require 'net/http'
require 'uri'
require 'cgi'

class KohaWebInstallAutomation

  def initialize (uri, user, pass)

    @uri = uri
    @user = user
    @pass = pass
    @path = ''
    @browser = Watir::Browser.new :phantomjs
    @previousStep = 0
    test_response_code

  end

  def test_response_code

    response = Net::HTTP.get_response URI.parse @uri #default is :follow_redirect => false

    case response
      when Net::HTTPSuccess
      #check what the URI actually is
        location = response['location']
        case location
          when location == @uri
            STDOUT.puts  "{\"comment\":\"Instance is already installed\"}"
            exit 0
          else
            raise "HTTPSuccess, but it is unclear how we got to" + @uri
        end
      when Net::HTTPRedirection
        @path = response['location']
        clickthrough_installer
      else
        raise "The response code was " + response
    end
  end

  def clickthrough_installer

    Watir.default_timeout = 5
    
    @browser.goto @uri + @path

    if @browser.execute_script("return document.readyState") == "complete"
      if @browser.url == @uri + @path
        begin
          step = CGI.parse(URI.parse(@uri + @path).query)["step"][0].to_i
        rescue
          #
        end

        case step
        when 1
          step_one
        when 2
          step_two
        when 3
          step_three
        else
          step_one # default to step one
        end
      else
        raise "Installer not found at expected url " + @uri + @path + ", instead got " + @browser.url.to_s
      end
    end
  end
  
  def do_login
    form = @browser.form(:id => "mainform")
    form.text_field(:id => "userid").set @user
    form.text_field(:id => "password").set @pass
    form.submit
  end

  def step_one
    if @previousStep != 0
      raise "Error step one: expected previous step to be 0, but got #{@previousStep}"
    end
    begin
      do_login
    rescue => e
      raise "Error in webinstaller step one: #{e}"
    end
    @previousStep = 1
    @browser.form(:name => "language").submit
    @browser.form(:name => "checkmodules").submit
    @path = '/cgi-bin/koha/installer/install.pl?step=2'
    clickthrough_installer
  end

  def step_two
    if @previousStep != 1
      raise "Error step two: expected previous step to be 1, but got #{@previousStep}"
    end
    begin
      @browser.form(:name => "checkinformation").submit
      @browser.form(:name => "checkdbparameters").submit
      @browser.form().submit
      @browser.form().submit
      @browser.link(:href => "install.pl?step=3&op=choosemarc").click
      @browser.radio(:name => "marcflavour", :value => "MARC21").set
      @browser.form(:name => "frameworkselection").submit
      @browser.form(:name => "frameworkselection").submit
    rescue => e
      raise "Error in webinstaller step two: #{e}"
    end
    @previousStep = 2
    step_three # need to run step 3 directly
  end

  def step_three

    begin
      if @previousStep == 0
        do_login
        @browser.link(:href => "install.pl?step=3&op=updatestructure").click
      elsif @previousStep == 2
        @browser.form().submit
      else
        raise "Error step three: expected previous step to be 0 or 2, but got #{@previousStep}"
      end
    rescue => e
      raise "Error in webinstaller step three: #{e}"
    end
    STDOUT.puts "{\"comment\":\"Successfully completed the install process\"}"
    @browser.close
    exit 0
  end

end