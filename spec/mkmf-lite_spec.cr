require "./spec_helper"

def example(string, &block)
  it(string, &block)
end

class Subject
  include Mkmf::Lite
end

describe Mkmf::Lite do
  subject = Subject.new
  st_type = "struct stat"
  st_member = "st_uid"
  st_header = "sys/stat.h"

  describe "have_header" do
    example "have_header returns expected boolean value" do
      subject.have_header("stdio.h").should eq(true)
      subject.have_header("foobar.h").should eq(false)
    end

    example "have_header accepts an array of directories as a second argument" do
      subject.have_header("stdio.h", ["/usr/local/include"]).should eq(true)
      subject.have_header("stdio.h", ["/usr/local/include", "/usr/include"]).should eq(true)
    end
  end

  describe "have_func" do
    example "have_func with no header argument returns expected boolean value" do
      subject.have_func("abort").should eq(true)
      subject.have_func("abortxyz").should eq(false)
    end

    example "have_func with arguments returns expected boolean value" do
      subject.have_func("printf", "stdio.h").should eq(true)
      subject.have_func("printfx", "stdio.h").should eq(false)
    end
  end

  context "have_struct_member" do
    example "have_struct_member returns expected boolean value" do
      subject.have_struct_member(st_type, st_member, st_header).should eq(true)
      subject.have_struct_member(st_type, "pw_bogus", st_header).should eq(false)
      subject.have_struct_member(st_type, st_member).should eq(false)
    end

<<-HERE
    example "have_struct_member requires at least two arguments" do
      expect{ subject.have_struct_member() }.to raise_error(ArgumentError)
      expect{ subject.have_struct_member("struct passwd") }.to raise_error(ArgumentError)
    end

    example "have_struct_member accepts a maximum of three arguments" do
      expect{ subject.have_struct_member("struct passwd", "pw_name", "pwd.h", true) }.to raise_error(ArgumentError)
    end
HERE
  end
end
