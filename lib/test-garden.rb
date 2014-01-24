require 'wrong'
include Wrong::Assert

if Wrong.config[:color]
  require "wrong/rainbow"
else
  class String
    def color(*); self; end
    def bright; self; end
  end
end

# Not directly instantiated by the user. See README and examples.
class TestGarden
  # Array of nested topics in descending order from the main topic to the topic
  # of the current test.
  attr_reader :stack
  
  # Hash of counters for pass, fail, skip, error cases.
  attr_reader :status
  
  # Array of regexes that restrict which topics are traversed.
  attr_reader :pattern
  
  # Stack of arrays of procs that will be called to tear down the current setup.
  attr_reader :teardowns

  VERSION = '0.4'

  class IncompleteTest < StandardError; end

  # Reads params from command line, or from given array of strings. If
  # passing an array, you should call this method *before* all tests.
  def self.params argv=ARGV
    @params ||= {
      :verbose => argv.delete("-v") || argv.delete("--verbose"),
      :pattern => argv.map {|arg| /#{arg}/i}
    }
  end
  
  # By default, share params for all TestGardens, but allow per-instance
  # variation by modifying the params hash.
  def params
    @params ||= self.class.params.dup
  end
  
  def initialize
    @pos = []
    @next = nil
    @did_one_test = false
    @stack = []
    @status = Hash.new(0)
    @enabled = false
    @pattern = params[:pattern]
    @teardowns = []
    @finishing = false
  end
  
  def enabled?
    @enabled
  end
  
  def verbose?
    params[:verbose]
  end

  def nest topic
    topic = topic.to_s
    @main_topic ||= topic

    if @did_one_test
      if not @next
        @next = @pos.dup
      end
      @pos[-1] += 1 if @pos.length > 0
      return
    end
    
    if @next
      len = [@pos.length, @next.length].min
      if @next[0...len] != @pos[0...len]
        @pos[-1] += 1 if @pos.length > 0
        return
      end
      
      if @next == @pos
        @next = nil
      end
    end
        
    begin
      stack.push topic
      @pos << 0
      teardowns << []
      old_enabled = @enabled
      @enabled = pattern.zip(stack).all? {|pat,subj| !subj or pat === subj}
      if enabled?
        puts "T: #{stack.join(": ")}" if verbose?
        @finishing = false
        catch :break_test do
          yield
          @finishing = stack.dup
        end
      else
        puts "S: #{stack.join(": ")}" if verbose?
        status[:skip] += 1
      end
    
    ensure
      if not @did_one_test
        @did_one_test = true
      else
        @finishing = false
      end

      @enabled = old_enabled
      @pos.pop
      stack.pop
      @pos[-1] += 1 if @pos.length > 0
    end
  end
  
  def do_teardowns
    teardowns.pop.reverse_each {|block| block.call}
  end
  
  def print_report
    ps = "%3d passed" % status[:pass]
    fs = "%3d failed" % status[:fail]
    fs = fs.color(:yellow) if status[:fail] > 0
    ss = "%3d skipped" % status[:skip]
    es = "%3d errors" % status[:err]
    es = es.color(:red) if status[:err] > 0
    report = [ps,fs,ss,es].join(", ")
    
    inc = status[:incomplete]
    if inc > 0
      is = "%3d incomplete" % inc
      is = is.color(:white)
      report << ", #{is}"
    end
    
    line = "#{report} in #{@main_topic}"
    line = line.bright if verbose?
    puts line
  end

  def handle_test_exceptions
    yield

  rescue Wrong::Assert::AssertionFailedError => ex
    status[:fail] += 1
    line = nil
    ex.backtrace.reverse_each {|l| break if /wrong\/assert.rb/ =~ l; line = l}
    msg = "F: #{stack.join(": ")}: failed assertion, at #{line}"
    puts msg.color(:yellow), ex.message
    throw :break_test
  
  rescue IncompleteTest => ex
    status[:incomplete] += 1
    if verbose?
      msg = "I: #{stack.join(": ")}"
      msg = msg.color(:white)
      puts msg
    end
    throw :break_test

  rescue => ex
    status[:err]  += 1
    bt = []
    ex.backtrace.each {|l| break if /wrong\/assert.rb/ =~ l; bt << l}
    bts = bt.join("\n  from ")
    msg = "E: #{stack.join(": ")}: #{ex} (#{ex.class}), at #{bts}"
    puts msg.color(:red)
    throw :break_test

  else
    if enabled?
      if @finishing
        status[:pass] += 1
        puts "P: #{@finishing.join(": ")}" if verbose?
        @finishing = false
      end
    else
      raise
    end
  end
  
  def main topic
    begin
      nest topic do
        handle_test_exceptions do
          yield
          do_teardowns
        end
      end
      @did_one_test = false
    end while @next
  ensure
    print_report
  end
end

# Begin a test block. The topic can be any object; its to_s method is applied
# to generate the output string. A class or string is typical.
#
# The block can include essentially any code, including more #test calls,
# method calls that call #test, assert{} and teardown{} calls, etc.
#
# If the block is omitted, then the test is assumed to be incomplete, perhaps
# a stub indicating future work. Incomplete tests are counted and reported.
def test topic
  if @test
    @test.nest topic do
      @test.handle_test_exceptions do
        if block_given?
          yield
          @test.do_teardowns
        else
          raise TestGarden::IncompleteTest
        end
      end
    end
    
  else
    begin
      @test = TestGarden.new
      @test.main topic do
        if block_given?
          yield
        else
          raise TestGarden::IncompleteTest
        end
      end
    ensure
      @test = nil
    end
  end
end

# Alternative to putting the teardown code after all relevant tests.
# This can be used to keep related setup and teardown code together.
# Teardows are executed in the reverse of their creation order.
def teardown(&block)
  if @test
    @test.teardowns.last << block
  else
    raise "Cannot teardown: not in a test"
  end
end
