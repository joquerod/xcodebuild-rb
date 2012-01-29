require 'spec_helper'

describe XcodeBuild::BuildReporter do
  let(:reporter) { XcodeBuild::BuildReporter.new }
  
  shared_examples_for "any build" do
    it "reports the build target" do
      reporter.build.target.should == "ExampleProject"
    end
    
    it "reports the project name" do
      reporter.build.project_name.should == "ExampleProject"
    end
    
    it "reports the build configuration" do
      reporter.build.configuration.should == "Release"
    end
    
    it "reports if the build configuration was the default" do
      reporter.build.should be_default_configuration
    end
  end
  
  context "when receiving events" do
    let(:delegate) { mock('reporter delegate').as_null_object }
    
    before do
      reporter.delegate = delegate
      
      # let's assume it responds to all delegate methods
      delegate.stub(:respond_to?).with(anything).and_return(true)
    end
    
    it "notifies it's delegate that a build has started" do
      delegate.should_receive(:build_started).with instance_of(XcodeBuild::BuildReporter::Build)
      
      event({:build_started=>
        {:target=>"ExampleProject",
         :project=>"ExampleProject",
         :configuration=>"Release",
         :default=>true}})
    end
    
    it "notifies it's delegate when a build action begins" do
      assume_build_started
      
      delegate.should_receive(:build_action_started).with instance_of(XcodeBuild::BuildReporter::BuildAction)
      
      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
    end
    
    it "notifies it's delegate when a previous build action finishes" do
      assume_build_started

      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
           
      delegate.should_receive(:build_action_finished).with reporter.build.last_action
           
      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
    end
    
    it "notifies it's delegate when the last build action finishes and the build is successful" do
      assume_build_started

      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
           
      delegate.should_receive(:build_action_finished).with reporter.build.last_action
           
      event({:build_succeeded=>{}})
    end
    
    it "notifies it's delegate when the last build action finishes and the build fails" do
      assume_build_started

      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
           
      delegate.should_receive(:build_action_finished).with reporter.build.last_action
           
      event({:build_succeeded=>{}})
    end
    
    it "notifies it's delegate that the build has finished when it is successful" do
      assume_build_started
      delegate.should_receive(:build_finished).with(reporter.build)
      event({:build_succeeded=>{}})
    end
    
    it "notifies it's delegate that the build has finished when it fails" do
      assume_build_started
      delegate.should_receive(:build_finished).with(reporter.build)
      event({:build_failed=>{}})
    end
  end
  
  context "once a build has started" do
    before do
      event({:build_started=>
        {:target=>"ExampleProject",
         :project=>"ExampleProject",
         :configuration=>"Release",
         :default=>true}})
    end
    
    it "reports that the build is running" do
      reporter.build.should be_running
    end
    
    it "reports that the build is not finished" do
      reporter.build.should_not be_finished
    end
  end
  
  context "once a simple, successful build has finished" do
    before do
      event({:build_started=>
        {:target=>"ExampleProject",
         :project=>"ExampleProject",
         :configuration=>"Release",
         :default=>true}})
         
      event({:build_action=>
        {:type=>"CpResource",
         :arguments=>
          ["/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/ResourceRules.plist",
           "build/Release-iphoneos/ExampleProject.app/ResourceRules.plist"]}})
           
      event({:build_action=>
        {:type=>"ProcessInfoPlistFile",
         :arguments=>
          ["build/Release-iphoneos/ExampleProject.app/Info.plist",
           "ExampleProject/ExampleProject-Info.plist"]}})
           
      event({:build_action=>
        {:type=>"CompileC",
         :arguments=>
          ["build/ExampleProject.build/Release-iphoneos/ExampleProject.build/Objects-normal/armv7/AppDelegate.o",
           "ExampleProject/AppDelegate.m",
           "normal",
           "armv7",
           "objective-c",
           "com.apple.compilers.llvm.clang.1_0.compiler"]}})
           
      event({:build_succeeded=>{}})
    end
    
    it_behaves_like "any build"
    
    it "reports that the build was successful" do
      reporter.build.should be_successful
    end
    
    it "reports the total number of completed build actions" do
      reporter.build.should have(3).actions_completed
    end
    
    it "reports that the build is not running" do
      reporter.build.should_not be_running
    end
    
    it "reports that the build is finished" do
      reporter.build.should be_finished
    end
  end
  
  context "once a simple, failed build has finished" do
    before do
      event({:build_started=>
        {:target=>"ExampleProject",
         :project=>"ExampleProject",
         :configuration=>"Release",
         :default=>true}})

      event({:build_action=>
        {:type=>"CompileC",
         :arguments=>
          ["build/ExampleProject.build/Release-iphoneos/ExampleProject.build/Objects-normal/armv7/AppDelegate.o",
           "ExampleProject/AppDelegate.m",
           "normal",
           "armv7",
           "objective-c",
           "com.apple.compilers.llvm.clang.1_0.compiler"]}})
           
      event({:build_error_detected=>
         {:file=>
           "/Users/luke/Code/mine/xcodebuild/resources/ExampleProject/ExampleProject/main.m",
          :line=>16,
          :char=>42,
          :message=>"expected ';' after expression [1]"}})
      
      event({:build_action=>
        {:type=>"CompileC",
         :arguments=>
          ["build/ExampleProject.build/Release-iphoneos/ExampleProject.build/Objects-normal/armv7/AppDelegate.o",
           "ExampleProject/AppDelegate.m",
           "normal",
           "armv7",
           "objective-c",
           "com.apple.compilers.llvm.clang.1_0.compiler"]}})
           
      event({:build_failed=>{}})
      
      event({:build_action_failed=>
        {:type=>"CompileC",
         :arguments=>
          ["build/ExampleProject.build/AlwaysFails-iphoneos/ExampleProject.build/Objects-normal/armv7/AppDelegate.o",
           "ExampleProject/AppDelegate.m",
           "normal",
           "armv7",
           "objective-c",
           "com.apple.compilers.llvm.clang.1_0.compiler"]}})
    end
    
    it_behaves_like "any build"
    
    it "reports that the build was a failure" do
      reporter.build.should be_failed
    end
    
    it "reports the total number of completed build actions" do
      reporter.build.should have(2).actions_completed
    end
    
    it "reports the total number of failed build actions" do
      reporter.build.should have(1).failed_actions
      reporter.build.failed_actions.first.tap do |action|
        action.type.should == "CompileC"
      end
    end
    
    it "reports the errors for each failed build action" do
      reporter.build.failed_actions.first.should have(1).errors
      reporter.build.failed_actions.first.errors.first.tap do |error|
        error.file.should == "/Users/luke/Code/mine/xcodebuild/resources/ExampleProject/ExampleProject/main.m"
        error.line.should == 16
        error.char.should == 42
        error.message.should == "expected ';' after expression [1]"
      end
    end
    
    it "reports that the build is not running" do
      reporter.build.should_not be_running
    end
    
    it "reports that the build is finished" do
      reporter.build.should be_finished
    end
  end
  
  private
  
  def event(event_data)
    message = event_data.keys.first
    params = event_data.values.first
    
    if params.any?
      reporter.send(message, params)
    else
      reporter.send(message)
    end
  end
  
  def assume_build_started
    event({:build_started=>
      {:target=>"ExampleProject",
       :project=>"ExampleProject",
       :configuration=>"Release",
       :default=>true}})
  end
end
