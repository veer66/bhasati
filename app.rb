require "gtk3"
require "fileutils"
require "launchy"
require "./app_conf"
require "./init_client"
require "./auth"
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
          end
          code_auth_dialog.present

        end
        auth_dialog.present

      end
    end
  end
end

app = BhasatiApp.new
app.run
