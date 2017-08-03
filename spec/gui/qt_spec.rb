# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby'
  require 'spec_helper'
  require 'cosmos/gui/qt'

  module Cosmos

    describe Qt do
      describe "Cosmos.getColor" do
        it "returns a Qt::Color when given a Qt::Color" do
          expect(Cosmos.getColor(Qt::Color.new('red'))).to be_instance_of(Qt::Color)
        end

        it "returns a Qt::Pen when given a Qt::Pen" do
          expect(Cosmos.getColor(Qt::Pen.new)).to be_instance_of(Qt::Pen)
        end

        it "returns a Qt::LinearGradient when given a Qt::LinearGradient" do
          expect(Cosmos.getColor(Qt::LinearGradient.new)).to be_instance_of(Qt::LinearGradient)
        end

        context "when given a string" do
          it "processes 'white'" do
            expect(Cosmos.getColor('white')).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor('white').rgb()).to eql 0xFFFFFFFF
          end
          it "processes 'black'" do
            expect(Cosmos.getColor('black')).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor('black').rgb()).to eql 0xFF000000
          end
          it "processes 'red'" do
            expect(Cosmos.getColor('red')).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor('red').rgb()).to eql 0xFFFF0000
          end
          it "processes 'lime'" do
            expect(Cosmos.getColor('lime')).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor('lime').rgb()).to eql 0xFF00FF00
          end
          it "processes 'blue'" do
            expect(Cosmos.getColor('blue')).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor('blue').rgb()).to eql 0xFF0000FF
          end
        end

        context "when given a Qt::Enum" do
          it "processes Qt::white" do
            expect(Cosmos.getColor(Qt::white)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(Qt::white).rgb()).to eql 0xFFFFFFFF
          end
          it "processes Qt::black" do
            expect(Cosmos.getColor(Qt::black)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(Qt::black).rgb()).to eql 0xFF000000
          end
          it "processes Qt::red" do
            expect(Cosmos.getColor(Qt::red)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(Qt::red).rgb()).to eql 0xFFFF0000
          end
          it "processes Qt::green" do
            expect(Cosmos.getColor(Qt::green)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(Qt::green).rgb()).to eql 0xFF00FF00
          end
          it "processes Qt::blue" do
            expect(Cosmos.getColor(Qt::blue)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(Qt::blue).rgb()).to eql 0xFF0000FF
          end
        end

        context "when given rgb values" do
          it "processes FF,FF,FF" do
            expect(Cosmos.getColor(0xFF,0xFF,0xFF)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(0xFF,0xFF,0xFF).rgb()).to eql 0xFFFFFFFF
          end
          it "processes 00,00,00 " do
            expect(Cosmos.getColor(0,0,0)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(0,0,0).rgb()).to eql 0xFF000000
          end
          it "processes FF,00,00" do
            expect(Cosmos.getColor(0xFF,0,0)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(0xFF,0,0).rgb()).to eql 0xFFFF0000
          end
          it "processes 00,FF,00" do
            expect(Cosmos.getColor(0,0xFF,0)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(0,0xFF,0).rgb()).to eql 0xFF00FF00
          end
          it "processes 00,00,FF" do
            expect(Cosmos.getColor(0,0,0xFF)).to be_instance_of(Qt::Color)
            expect(Cosmos.getColor(0,0,0xFF).rgb()).to eql 0xFF0000FF
          end
        end

      end
    end

  end # module Cosmos
end
