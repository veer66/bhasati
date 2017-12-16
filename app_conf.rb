require 'toml'

class AppConf
  def initialize(path)
    @path = path
  end

  def load
    if File.exists?(@path)
      TOML.load_file(@path)
    else
      {"app" => {},
       "user" => {}}
    end    
  end

  def save(conf)
    File.open(@path, "w") do |f|
      f.puts TOML::Generator.new(conf).body
    end
  end
end
