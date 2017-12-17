require "gtk3"
require "fileutils"
require "launchy"
require "mastodon"
require "./app_conf"
require "./init_client"
require "./auth"
require "./util"
require "pp"

current_path = File.expand_path(File.dirname(__FILE__))
data_path = "#{current_path}/data"
gresource_bin = "#{data_path}/bhasati.gresource"
gresource_xml = "#{data_path}/bhasati.gresource.xml"

res_dir = File.dirname("bhasati.gresource.xml")

system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", File.dirname(gresource_xml),
       gresource_xml)

resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)

at_exit do
  FileUtils.rm_f gresource_bin
end

$app_conf = AppConf.new(".bhasati.toml")
$conf = $app_conf.load

class MastoAuthDialog < Gtk::Dialog
  type_register
  class << self
    def init
      set_template(:resource => "/rocks/veer66/bhasati/auth-dialog.ui")
      bind_template_child("login_button")
      bind_template_child("server_url_entry")
    end
  end

  def initialize(parent)
    super(:transient_for => parent, :use_header_bar => 0)
  end
end

class CodeAuthDialog < Gtk::Dialog
  type_register
  class << self
    def init
      set_template(:resource => "/rocks/veer66/bhasati/code-auth-dialog.ui")
      bind_template_child("login_button")
      bind_template_child("code_entry")
    end
  end

  def initialize(parent)
    super(:transient_for => parent, :use_header_bar => 0)
  end
end

class MainWin < Gtk::ApplicationWindow
  type_register
  class << self
    def init
      set_template(:resource => "/rocks/veer66/bhasati/window.ui")
      bind_template_child("home_list_box")
      bind_template_child("noti_list_box")
    end
  end
  
  def initialize(application)
    super(:application => application)
  end
end

class BhasatiApp < Gtk::Application
  def initialize
    super("rocks.veer66.bhasati", :flags_none)
    @can_start = false
    @period = 300

    Thread.new do
      loop do
        update if @can_start
        sleep(@period)
      end        
    end

    signal_connect "activate" do |application|
      @window = MainWin.new(application)
      @window.present

      unless $conf["user"] and $conf["user"]["access_token"]
        auth_dialog = MastoAuthDialog.new(window)
        auth_dialog.login_button.signal_connect "clicked" do |but|
          auth_dialog.close
          init_client($conf, auth_dialog.server_url_entry.text)
          auth_url = create_auth_url($conf)
          Launchy.open(auth_url)
          code_auth_dialog = CodeAuthDialog.new(window)
          code_auth_dialog.login_button.signal_connect "clicked" do |but|
            code_auth_dialog.close
            get_access_token($conf, code_auth_dialog.code_entry.text)
            $app_conf.save $conf
            first_start_client
          end
          code_auth_dialog.present
        end
        auth_dialog.present
      else
        first_start_client
      end
    end
  end

  def first_start_client
    Thread.new do
      update
      @can_start = true
    end
  end

  def update_home_timeline
    client = Mastodon::REST::Client.new(base_url: $conf["user"]["base_url"],
                                        bearer_token: $conf["user"]["access_token"])
    
    client.home_timeline.each do |status|
      vbox = Gtk::Box.new(Gtk::Orientation::VERTICAL)

      acc_label = Gtk::Label.new
      acc_label.text = "@#{status.account.display_name}"
      acc_label.halign = "start"
      vbox.pack_start(acc_label, :expand => true, :fill => true, :padding => 2)

      content = plainize(status.content)
      content_label = Gtk::Label.new
      content_label.text = content
      content_label.wrap = true
      content_label.halign = "start"
      
      vbox.pack_start(content_label, :expand => false, :fill => false, :padding => 7)
      vbox.hexpand = false
      vbox.halign = "start"
      
      vbox.show_all
      @window.home_list_box << vbox
    end
  end

  def update_notifications
    client = Mastodon::REST::Client.new(base_url: $conf["user"]["base_url"],
                                        bearer_token: $conf["user"]["access_token"])

    client.notifications.each do |noti|
      vbox = Gtk::Box.new(Gtk::Orientation::VERTICAL)

      acc_label = Gtk::Label.new
      acc_label.text = "[#{noti.type}] @#{noti.account.display_name}"
      acc_label.halign = "start"
      vbox.pack_start(acc_label, :expand => true, :fill => true, :padding => 2)

      content = plainize(noti.status.content)
      content_label = Gtk::Label.new
      content_label.text = content
      content_label.wrap = true
      content_label.halign = "start"
      vbox.pack_start(content_label, :expand => false, :fill => false, :padding => 7)
      
      vbox.hexpand = false
      vbox.halign = "start"
      vbox.show_all
      
      @window.noti_list_box << vbox
    end

  end
  
  def update
    thrs = []
    thrs << Thread.new { update_home_timeline }
    thrs << Thread.new { update_notifications }
    thrs.each {|thr| thr.join}
  end
end

app = BhasatiApp.new
app.run
