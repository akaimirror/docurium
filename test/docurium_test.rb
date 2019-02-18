require 'minitest/autorun'
require 'docurium'
require 'rugged'

class DocuriumTest < Minitest::Test

  def setup
    @dir = Dir.mktmpdir()

    @repo = Rugged::Repository.init_at(@dir, :bare)

    config = <<END
{
 "name":   "libgit2",
 "github": "libgit2/libgit2",
 "prefix": "git_",
 "branch": "gh-pages"
}
END

    # Create an index as we would have read from the user's repository
    index = Rugged::Index.new
    headers = File.dirname(__FILE__) + '/fixtures/git2/'
    Dir.entries(headers).each do |rel_path|
      path = File.join(headers, rel_path)
      next if File.directory? path
      id = @repo.write(File.read(path), :blob)
      index.add(:path => rel_path, :oid => id, :mode => 0100644)
    end

    @path = File.dirname(__FILE__) + '/fixtures/git2/api.docurium'
    @doc = Docurium.new(@path, @repo)
    @data = @doc.parse_headers(index, 'HEAD')
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_can_parse_headers
    keys = @data.keys.map { |k| k.to_s }.sort
    assert_equal ['callbacks', 'files', 'functions', 'globals', 'groups', 'prefix', 'types'], keys
    assert_equal 154, @data[:functions].size
  end

  def test_can_extract_enum_from_define
    skip("this isn't something we do")
    assert_equal 41, @data[:globals].size
    idxentry = @data[:types].find { |a| a[0] == 'GIT_IDXENTRY' }
    assert idxentry
    assert_equal 75, idxentry[1][:lineto]
    # this one is on the last doc block
    assert idxentry[1][:block].include? 'GIT_IDXENTRY_EXTENDED2'
    # from an earlier block, should not get overwritten
    assert idxentry[1][:block].include? 'GIT_IDXENTRY_UPDATE'
  end

  def test_can_extract_structs_and_enums
    skip("we don't auto-create enums, so the number is wrong")
    assert_equal 25, @data[:types].size
  end

  def test_can_find_type_usage
    oid = @data[:types].assoc('git_oid')
    assert_equal 10, oid[1][:used][:returns].size
    assert_equal 39, oid[1][:used][:needs].size
  end

  def test_can_parse_normal_functions
    func = @data[:functions]['git_blob_rawcontent']
    assert_equal "<p>Get a read-only buffer with the raw content of a blob.</p>\n",  func[:description]
    assert_equal 'const void *',  func[:return][:type]
    assert_equal ' the pointer; NULL if the blob has no contents',  func[:return][:comment]
    assert_equal 84,              func[:line]
    assert_equal 84,              func[:lineto]
    assert_equal 'blob.h',        func[:file]
    assert_equal 'git_blob *blob',func[:argline]
    assert_equal 'blob',          func[:args][0][:name]
    assert_equal 'git_blob *',    func[:args][0][:type]
    assert_equal 'pointer to the blob',  func[:args][0][:comment]
  end

  def test_can_parse_defined_functions
    func = @data[:functions]['git_tree_lookup']
    assert_equal 'int',     func[:return][:type]
    assert_equal ' 0 on success; error code otherwise',     func[:return][:comment]
    assert_equal 50,        func[:line]
    assert_equal 'tree.h',  func[:file]
    assert_equal 'id',               func[:args][2][:name]
    assert_equal 'const git_oid *',  func[:args][2][:type]
    assert_equal 'identity of the tree to locate.',  func[:args][2][:comment]
  end

  def test_can_parse_function_cast_args
    func = @data[:functions]['git_reference_listcb']
    assert_equal 'int',             func[:return][:type]
    assert_equal ' 0 on success; error code otherwise',  func[:return][:comment]
    assert_equal 321,               func[:line]
    assert_equal 'refs.h',          func[:file]
    assert_equal 'repo',              func[:args][0][:name]
    assert_equal 'git_repository *',  func[:args][0][:type]
    assert_equal 'list_flags',      func[:args][1][:name]
    assert_equal 'unsigned int',    func[:args][1][:type]
    assert_equal 'callback',        func[:args][2][:name]
    assert_equal 'int (*)(const char *, void *)', func[:args][2][:type]
    assert_equal 'Function which will be called for every listed ref', func[:args][2][:comment]
    assert_equal 8, func[:comments].split("\n").size
  end

  def test_can_get_the_full_description_from_multi_liners
    func = @data[:functions]['git_commit_create_o']
    desc = "<p>Create a new commit in the repository using <code>git_object</code>\n instances as parameters.</p>\n"
    assert_equal desc, func[:description]
  end

  def test_can_group_functions
    assert_equal 15, @data[:groups].size
    group, funcs = @data[:groups].first
    assert_equal 'blob', group
    assert_equal 6, funcs.size
  end

  def test_can_store_mutliple_enum_doc_sections
    skip("this isn't something we do")
    idxentry = @data[:types].find { |a| a[0] == 'GIT_IDXENTRY' }
    assert idxentry, "GIT_IDXENTRY did not get automatically created"
    assert_equal 2, idxentry[1][:sections].size
  end

  def test_can_parse_callback
    cb = @data[:callbacks]['git_callback_do_work']
    # we can mostly assume that the rest works as it's the same as for the functions
    assert_equal 'int', cb[:return][:type]
  end

end
