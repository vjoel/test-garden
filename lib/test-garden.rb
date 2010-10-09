require 'wrong'
include Wrong::Assert

# A garden of forking tests. TestGarden excels at concise tests that share
# several stages of setup code. The shared code is executed once for each
# test that needs it.
#
# TestGarden also generates nice summary output, showing how many pass, fail,
# skip, and error cases were detected for each group of tests.
class TestGarden
  # Array of topics descending from the main topic to the topic most narrowly
  # containing the current test position.
  attr_reader :stack
  
  # Hash of counters for pass, fail, skip, error cases.
  attr_reader :status
  
  # Array of regexes that restrict which topics are traversed.
  attr_reader :pattern
  
  # Stack of arrays of procs that will be called tear down the current setup.
  attr_reader :teardowns
  
  # Read params from command line, or from given array. If passing an
  # array, call this method *before* all tests.
  def self.params argv=ARGV
    @params ||= {
      :verbose => argv.delete("-v") || argv.delete("--verbose"),
      :pattern => argv.map {|arg| /#{arg}/i}
    }
  end
  
  # By default, share params for all TestGardens, but allow per-instance diffs.
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
        if verbose?
          puts "T: #{stack.join(": ")}"
        end
        catch :break_test do
          yield
        end
      else
        status[:skip] += 1
      end
    
    ensure
      teardowns.pop.reverse_each {|block| block.call}
      @enabled = old_enabled
      @pos.pop
      stack.pop
      @did_one_test = true
      @pos[-1] += 1 if @pos.length > 0
    end
  end
  
  def print_report
    ps = "%3d passed" % status[:pass]
    fs = "%3d failed" % status[:fail]
    fs = fs.color(:yellow) if status[:fail] > 0
    ss = "%3d skipped" % status[:skip]
    es = "%3d errors" % status[:err]
    es = es.color(:red) if status[:err] > 0
    report = [ps,fs,ss,es].join(", ")
    puts "#{report} in #{@main_topic}"
  end

  def handle_test_results
    yield

  rescue Wrong::Assert::AssertionFailedError => ex
    status[:fail] += 1
    line = nil
    ex.backtrace.reverse_each {|l| break if /wrong\/assert.rb/ =~ l; line = l}
    msg = "F: #{stack.join(": ")}: failed assertion, at #{line}"
    puts msg.color(:yellow), ex.message
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
      status[:pass] += 1
    else
      raise
    end
  end
  
  def main topic
    begin
      nest topic do
        handle_test_results do
          yield
        end
      end
      @did_one_test = false
    end while @next
  ensure
    print_report
  end
end

def test topic
  if @test
    @test.nest topic do
      @test.handle_test_results do
        yield
      end
    end
    
  else
    begin
      @test = TestGarden.new
      @test.main topic do
        yield
      end
    ensure
      @test = nil
    end
  end
end

# Alternative to putting the teardown code after all relevant tests.
# This can be used to keep related setup and teardown code together.
def teardown(&block)
  if @test
    @test.teardowns.last << block
  else
    raise "Cannot teardown: not in a test"
  end
end
