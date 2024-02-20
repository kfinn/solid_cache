# frozen_string_literal: true

require "test_helper"

module SolidCache
  class EntrySizeMovingAverageEstimateTest < ActiveSupport::TestCase
    test "write and read cache entries" do
      assert_equal 0, estimate(samples: 10)
    end

    test "gets exact estimate when samples sizes are big enough" do
      write_entries(value_lengths: [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ])

      estimate = Entry::Size::MovingAverageEstimate.new(samples: 12)
      assert_predicate estimate, :exact?
      assert_equal 415, estimate.size
    end

    test "tracks moving average" do
      write_entries(value_lengths: 5000.times.to_a)

      Entry.write Entry::Size::MovingAverageEstimate::ESTIMATES_KEY, "4637774|4754378|7588547"

      with_fixed_srand(1) do
        assert_equal 10075987, estimate(samples: 1)
      end

      assert_equal "4754378|7588547|17885035", Entry.read(Entry::Size::MovingAverageEstimate::ESTIMATES_KEY)
    end

    test "appends to moving average when less than required items" do
      write_entries(value_lengths: 5000.times.to_a)

      assert_nil Entry.read(Entry::Size::MovingAverageEstimate::ESTIMATES_KEY)

      with_fixed_srand(1) { assert_equal 19872121, estimate(samples: 2) }

      assert_equal "19872121", Entry.read(Entry::Size::MovingAverageEstimate::ESTIMATES_KEY)

      with_fixed_srand(2) { assert_equal 11077118, estimate(samples: 2) }

      assert_equal "19872121|2282115", Entry.read(Entry::Size::MovingAverageEstimate::ESTIMATES_KEY)
    end

    private
      def write_entries(value_lengths:)
        Entry.write_multi(value_lengths.map.with_index { |value_length, index| { key: "key#{index.to_s.rjust(5, "0")}", value: "a" * value_length } })
      end

      def with_fixed_srand(seed)
        old_srand = srand(seed)
        yield
      ensure
        srand(old_srand)
      end

      def estimate(samples:)
        Entry::Size::MovingAverageEstimate.new(samples: samples).size
      end
  end
end
