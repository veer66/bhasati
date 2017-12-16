require "gtk3"
require "./app_conf"
class AuthDialog < Gtk::Dialog
  type_register
  
end

require "fileutils"

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
      #bind_template_child("window")
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
      #bind_template_child("window")
    end
  end
  
  def initialize(application)
    super(:application => application)
  end
end

class BhasatiApp < Gtk::Application
  def initialize
    super("rocks.veer66.bhasati", :flags_none)
    signal_connect "activate" do |application|
      window = MainWin.new(application)
      window.present

      unless $conf["user"]["access_token"]
        auth_dialog = MastoAuthDialog.new(window)
        auth_dialog.present
      end
    end
  end
end

app = BhasatiApp.new
app.run
