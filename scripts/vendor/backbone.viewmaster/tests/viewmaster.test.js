/*global window:true,describe:true, it:true, expect: true, Backbone: true, beforeEach: true, chai:true, _:true*/
/*jshint expr:true */

describe("ViewMaster", function(){

  var Puppet = Backbone.ViewMaster.extend({
    name: "puppet",

    constructor: function(opts) {
      Backbone.ViewMaster.prototype.constructor.apply(this, arguments);
      if (opts && opts.name) {
        this.name = opts.name;
      }
    },

    template: function(){
      return "<h1 class=child>" + this.name + "</h1>";
    }
  });


  var Master = Backbone.ViewMaster.extend({
    template: function(){
      return '<div class="container"></div>';
    }
  });

  it("is installed to Backbone namespace", function(){
    expect(Backbone.ViewMaster).to.be.ok;
  });

  it("returns null for unknown view container", function() {
    var view = new Backbone.ViewMaster();
    expect(view.getViews("something")).to.eq(undefined);
  });

  it("Adds model to instance", function(){
    var model = new Backbone.Model();
    var view = new Backbone.ViewMaster({
      model: model
    });
    expect(view.model === model).to.be.ok;
  });


  it("renders child view from setView", function(){
    var m = new Master();
    m.setView(".container", new Puppet());
    m.render();
    expect(m.$el).to.have.text("puppet");
  });

  it("renders child view from setView using an array", function(){
    var m = new Master();
    m.setView(".container", [new Puppet()]);
    m.render();
    expect(m.$el).to.have.text("puppet");
  });


  it("does not render child views twice", function(){
    var m = new Master();
    var p = new Puppet();
    var spy = p.render = chai.spy(p.render);

    m.setView(".container", p);
    m.render();
    m.render();
    expect(spy).to.have.been.called.once;
  });


  it("only new child views are rendered on ViewMaster#render()", function(){
    var m = new Master();
    var first = new Puppet({ name: "first" });
    first.render = chai.spy(first.render);

    m.setView(".container", first);
    m.render();

    var second = new Puppet({ name: "second" });
    second.render = chai.spy(second.render);
    m.appendView(".container", second);
    m.renderViews();

    expect(first.render).to.have.been.called.once;
    expect(second.render).to.have.been.called.once;

    expect(m.$el).to.have(first.$el);
    expect(m.$el).to.have(second.$el);
  });

  describe("eachView()", function() {
    var parent = new Backbone.ViewMaster();
    parent.setView(".foo", new Backbone.ViewMaster());
    parent.setView(".bar", new Backbone.ViewMaster());

    it("can iterate all views", function() {
      var count = 0;
      parent.eachView(function() {
        count += 1;
      });

      expect(count).to.eq(2);
    });

    it("can iterate filtered views", function() {
      var count = 0;
      parent.eachView([".foo"], function() {
        count += 1;
      });

      expect(count).to.eq(1);
    });

  });

  it("can filter which containers are rendered", function() {
      var childA = new Backbone.ViewMaster();
      childA.template = function() {
        return "<p>childA</p>";
      };

      var childB = new Backbone.ViewMaster();
      childB.$el.detach = chai.spy(childB.$el.detach);
      childB.render = chai.spy(childB.render);
      childB.template = function() {
        return "<p>childB</p>";
      };

      var parent = new Backbone.ViewMaster();
      parent.template = function() {
        return "<div class=containerA ></div><div class=containerB ></div>";
      };

      parent.setView(".containerA", childA);
      parent.setView(".containerB", childB);
      parent.render();


      parent.renderViews({
        force: true,
        views: [ ".containerA" ]
      });

      expect(childB.render).to.have.been.called.once;
      expect(childB.$el.detach).to.have.been.called.once;

  });

  it("force option renders child views", function(){
    var m = new Master();
    var p = new Puppet();
    var spy = p.render = chai.spy(p.render);

    m.setView(".container", p);
    m.render();
    m.render({ force: true });
    expect(spy).to.have.been.called.twice;
  });

  it("can add new views with appendView() after initial render", function(){
    var m = new Master();
    m.setView(".container", new Puppet());
    m.render();

    m.appendView(".container", new Puppet({ name: "newview" }));
    m.render();
    var childs = m.$(".child");

    expect(childs[0].innerHTML).to.eq("puppet");
    expect(childs[1].innerHTML).to.eq("newview");
  });

  it("can insert view to specific index with insertView(...)", function(){
    var parent = new Master();
    parent.setView(".container", new Puppet());
    parent.render();

    var first = new Puppet({ name: "first" });
    var last = new Puppet({ name: "last" });
    parent.setView(".container", [first, last]);
    parent.render();

    expect(parent.$el).to.have(first.$el);
    expect(parent.$el).to.have(last.$el);

    var middle = new Puppet({ name: "middle" });
    parent.insertView(".container", 1, middle);
    parent.renderViews();

    expect(parent.$el).to.have(middle.$el);
    expect(parent.getViews(".container")).to.deep.eq([first, middle, last]);

  });

  it("can add new views with prependView() after initial render", function(){
    var m = new Master();
    m.setView(".container", new Puppet());
    m.render();

    m.prependView(".container", new Puppet({ name: "newview" }));
    m.renderViews();
    var childs = m.$(".child");
    expect(childs[1].innerHTML).to.eq("puppet");
    expect(childs[0].innerHTML).to.eq("newview");
  });

  it("updates view order", function(){
    var m = new Master();
    var first = new Puppet({ name: "first" });
    var second = new Puppet({ name: "second" });

    m.setView(".container", [first, second]);
    m.render();

    m.setView(".container", [second, first]);
    m.renderViews();

    var childs = m.$(".child");
    expect(childs[0].innerHTML).to.eq("second");
    expect(childs[1].innerHTML).to.eq("first");
  });

  it("setView&renderViews() removes old views", function(){
    var m = new Master();
    var views = [
      new Puppet({ name: "first" }),
      new Puppet({ name: "second" })
    ];

    m.setView(".container", views);
    m.render();

    m.setView(".container", views[1]);
    m.renderViews();

    expect(m.$el).to.not.have(views[0].$el);
    expect(m.$el).to.have(views[1].$el);

  });


  it("does not render already rendered views", function(){
    var master = new Master();
    var child = new Puppet();
    child.render = chai.spy(child.render);
    child.render();

    master.setView(".container", child);
    master.render();

    expect(child.render).to.have.been.called.once;
    expect(master.$el).to.have(child.$el);
  });

  it("child.remove() removes from parent", function(){
    var parent = new Master();
    var child = new Puppet({ name: "first" });

    parent.setView(".container", child);
    parent.render();
    expect(_.contains(parent.getViews(".container"), child)).to.be.ok;

    child.remove();
    parent.render();
    expect(parent.$el).to.not.have(child.$el);
    expect(_.contains(parent.getViews(".container"), child)).to.not.be.ok;
  });

  it("child.detach() removes from parent and DOM", function(){
    var parent = new Master();
    var child = new Puppet({ name: "first" });

    parent.setView(".container", child);
    parent.render();
    expect(_.contains(parent.getViews(".container"), child)).to.be.ok;

    child.detach();
    expect(parent.$el).to.not.have(child.$el);
    expect(_.contains(parent.getViews(".container"), child)).to.not.be.ok;
  });

  it("child.detach() does not clear dom events", function(){
    var child = new (Backbone.ViewMaster.extend({

      template: function() {
        return "<button>child</button>";
      },

      events: {
        "click button": "spy"
      },

      spy: chai.spy()

    }))();

    var parent = new Backbone.ViewMaster();
    parent.template = function() {
      return "<div class=container ></div>";
    };

    parent.setView(".container", child);
    parent.render();

    child.detach();
    child.$("button").click();
    expect(child.spy).to.have.been.called.once;
  });


  describe("with deeply nested views", function(){

    var ViewList = Backbone.ViewMaster.extend({
      template: function() {
        return '<h1>List<h1><div class="items"></div>';
      }
    });

    var Layout = Backbone.ViewMaster.extend({

      template: function() {
        return '<h1>Title<h1><div class="container"></div>';
      }

    });

    it("renders them all", function(){
      var children = [
        new Puppet({ name: "first" }),
        new Puppet({ name: "second" })
      ];
      var list = new ViewList();
      list.setView(".items", children);
      var layout = new Layout();
      layout.setView(".container", list);

      layout.render();

      expect(layout.$el).to.contain("List");
      expect(layout.$el).to.contain("first");
      expect(layout.$el).to.contain("second");

    });

    it("does not render nested views twice", function(){

      var children = [
        new Puppet({ name: "first" }),
        new Puppet({ name: "second" })
      ];

      var spy = children[1].render = chai.spy(children[1].render);

      var list = new ViewList();
      list.setView(".items", children);

      var layout = new Layout();
      layout.setView(".container", list);

      layout.render();
      layout.render();

      expect(spy).to.have.been.called.once;

    });

    it("option force calls nested views twice", function(){

      var children = [
        new Puppet({ name: "first" }),
        new Puppet({ name: "second" })
      ];

      var spy = children[1].render = chai.spy(children[1].render);

      var list = new ViewList();
      list.setView(".items", children);

      var layout = new Layout();
      layout.setView(".container", list);

      layout.render();
      layout.render({ force: true });

      expect(spy).to.have.been.called.twice;

    });

    it("can move child to other parent", function(){
      var Parent = Backbone.ViewMaster.extend({
        template: function() {
          return "<div class=container></div>";
        }
      });

      var parent1 = new Parent();
      var parent2 = new Parent();
      var child = new Backbone.ViewMaster();
      child.template = function() {
        return "<span class=child>child</span>";
      };

      parent1.setView(".container", child);
      parent1.render();

      parent2.setView(".container", child);

      parent2.render();
      parent1.render();

      expect(parent2.$el).to.have(child.$el);
      expect(parent1.$el).to.not.have(child.$el);

    });


  });

  describe("CoffeeScript", function() {
    it("works with CoffeeScript classes", function(done){
      var model = new Backbone.Model();
      model.on("done", done);

      var view = new window.CoffeeView({
        model: model
      });

      model.trigger("test");

    });
  });
});
