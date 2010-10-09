require File.expand_path('../lib/test-garden', File.dirname(__FILE__))

test "array" do
  # set up for each test in this block -- binding not shared between the two
  # tests below
  a = (0..10).to_a
  
  test "sort" do
    # do some further setup
    a << 3.5
    
    test "numerically" do
      a.sort!
        # destructive, but doesn't affect other tests
      assert {a.first == 0}
      assert {a[4] == 3.5}
    end
    
    test "lexicographically" do
      a = a.sort_by {|x|x.to_s}
      assert {a[6] == 4}
        # would fail if "a << 3.5" happened twice on the same array
    end
  end
end

# mock impl. of socket connecting to a little ftp-like server
# (of course it should use length fields, delims, or fixed length messages,
# but let's assume that's been abstracted somehow by a message layer)
class MockSocket
  def initialize(*)
    @closed = false
    @logged_in = false
    @buf = []
    @files = []
  end
  
  def close; @closed = true; end
  
  def closed?; @closed; end
  
  def send s
    raise if closed?
    if @logged_in
      case s
      when "ls"
        @buf << @files.join(",")
      when /\Aupload (.*)/m
        @files << $1
      when /\Arm (.*)/m
        @files.delete $1
      end
    else
      case s
      when "nobody"
        @buf << "go away"
      else
        @logged_in = true
        @buf << "hello"
      end
    end
  end
  
  def recv
    raise if closed?
    @buf.shift
  end
end

test "ftp server" do
  sock = MockSocket.new
  teardown {sock.close unless sock.closed?}
  
  test "bad login" do
    sock.send "nobody"
    s = sock.recv
    assert {s == "go away"}
  end
  
  test "good login" do
    sock.send "fred flintstone"
    s = sock.recv
    assert {s == "hello"}
    
    test "list files" do
      sock.send "ls"
      s = sock.recv
      assert {s == ""} # no files yet (regardless of test order!)
    end

    fox_chap_1 = "The quick brown fox jumped"
    fox_chap_2 = "over the lazy dog's back."

    test "upload file" do
      sock.send "upload #{fox_chap_1}"

      test "list files" do
        sock.send "ls"
        s = sock.recv
        assert {s == fox_chap_1}
      end

      test "delete file" do
        sock.send "rm #{fox_chap_1}"

        test "list files" do
          sock.send "ls"
          s = sock.recv
          assert {s == ""}
        end
      end

      test "upload another file" do
        sock.send "upload #{fox_chap_2}"

        test "list files" do
          sock.send "ls"
          a = sock.recv.split(",")
          assert {a.sort == [fox_chap_1, fox_chap_2].sort}
        end
      end
    end
  end
end
