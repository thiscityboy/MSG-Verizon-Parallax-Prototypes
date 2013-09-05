# encoding: utf-8
class MyApp < Sinatra::Application
  get "/" do
    erb :main
  end

  get "/bobble" do
    @css=%w(/css/bobble-bball.css)
   erb :bobble
  end

  get "/monitor" do
    erb :monitor, :layout => false
  end

  get "/incompatible" do
    erb :incompatible, :layout => false
  end
end
