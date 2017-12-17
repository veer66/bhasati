require "gtk3"
require "fileutils"
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
      bind_template_child("home_box")
      bind_template_child("noti_box")
      bind_template_child("toot_entry")
      bind_template_child("toot_button")
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
    @period = 60

    @home = []
    @home_id = {}
    @noti = []
    @noti_id = {}
    @max_list_len = 200
    
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
        auth_dialog = MastoAuthDialog.new(@window)
        auth_dialog.login_button.signal_connect "clicked" do |but|
          auth_dialog.close
          init_client($conf, auth_dialog.server_url_entry.text)
          auth_url = create_auth_url($conf)
          `xdg-open '#{auth_url}'`
          code_auth_dialog = CodeAuthDialog.new(@window)
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

  def toot(text)
    return nil if text.empty?
    Thread.new do
      client = create_client
      client.create_status(text)
      @window.toot_entry.text = ""
      update
    end
  end
  
  def first_start_client
    @window.toot_button.signal_connect "clicked" do |_|
      toot(@window.toot_entry.text)
    end
    
    Thread.new do
      update
      @can_start = true
    end
  end

  def add_to_home(status)
    vbox = Gtk::Box.new(Gtk::Orientation::VERTICAL)

    acc_label = Gtk::Label.new
    acc_label.text = "@#{status.account.display_name} #{status.created_at}"
    acc_label.halign = "start"
    vbox.pack_start(acc_label, :expand => true, :fill => true, :padding => 2)

    content = plainize(status.content)
    content_label = Gtk::Label.new
    content_label.text = content
    content_label.wrap = true
    content_label.halign = "start"
    
    vbox.pack_start(content_label, :expand => false, :fill => false, :padding => 2)
    vbox.hexpand = false
    vbox.halign = "start"
    
    vbox.show_all
    @window.home_box.pack_start(vbox, :expand => false, :fill => false, :padding => 7)

  end

  def create_client
    Mastodon::REST::Client.new(
      base_url: $conf["user"]["base_url"],
      bearer_token: $conf["user"]["access_token"])
  end
  
  def update_home_timeline
    client = create_client
    client.home_timeline.each do |status|
      @home << status unless @home_id.has_key?(status.id)
    end

    @home.sort_by! {|status| status.created_at}
    @home.reverse!
    @home = @home.take(@max_list_len)
    @home_id = {}
    @home.each{|status| @home_id[status.id] = true}
    @window.home_box.each{|child| @window.home_box.remove(child)}
    @home.each{|status| add_to_home(status)}                                                  
  end

  def add_to_noti(noti)
    vbox = Gtk::Box.new(Gtk::Orientation::VERTICAL)

    acc_label = Gtk::Label.new
    acc_label.text = "[#{noti.type}] @#{noti.account.display_name} #{noti.created_at}"
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
    
    @window.noti_box << vbox

  end
  
  def update_notifications
    client = create_client
    client.notifications.each do |noti|
      @noti << noti unless @noti_id.has_key?(noti.id)
    end

    @noti.sort_by! {|noti| noti.created_at}
    @noti.reverse!
    @noti = @noti.take(@max_list_len)
    @noti_id = {}
    @noti.each{|noti| @noti_id[noti.id] = true}
    @window.noti_box.each{|child| @window.noti_box.remove(child)}
    @noti.each{|noti| add_to_noti(noti)}                                                  
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
