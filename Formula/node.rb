class Node < Formula
  desc "Platform built on V8 to build network applications"
  homepage "https://nodejs.org/"
  url "https://nodejs.org/dist/v13.4.0/node-v13.4.0.tar.gz"
  sha256 "039e9bfbb114fca44b14f317cdadf51fc875660e4e03106fa303503add7ae560"
  head "https://github.com/nodejs/node.git"

  bottle do
    cellar :any
    sha256 "a641d0498d8f8d6b17fc8d50fd498aa6a000d3d3af4056a2cde14591c9d3542a" => :catalina
    sha256 "11762599e8c5fa17f26cbd33ff902b6eabf7bba007460fe81f1408c5b49c7f45" => :mojave
    sha256 "053f02a81756333e3d136abd82d365d17bc86e917335dfc2383021d035051f32" => :high_sierra
  end

  depends_on "pkg-config" => :build
  depends_on "python" => :build
  depends_on "icu4c"

  # We track major/minor from upstream Node releases.
  # We will accept *important* npm patch releases when necessary.
  resource "npm" do
    url "https://registry.npmjs.org/npm/-/npm-6.13.4.tgz"
    sha256 "a063290bd5fa06a8753de14169b7b243750432f42d01213fbd699e6b85916de7"
  end

  def install
    # make sure subprocesses spawned by make are using our Python 3
    ENV["PYTHON"] = Formula["python"].opt_bin/"python3"

    # Never install the bundled "npm", always prefer our
    # installation from tarball for better packaging control.
    args = %W[--prefix=#{prefix} --without-npm --with-intl=system-icu]
    args << "--tag=head" if build.head?

    system "./configure", *args
    system "make", "install"

    # Allow npm to find Node before installation has completed.
    ENV.prepend_path "PATH", bin

    bootstrap = buildpath/"npm_bootstrap"
    bootstrap.install resource("npm")
    system "node", bootstrap/"bin/npm-cli.js", "install", "-ddd", "--global",
            "--prefix=#{libexec}", resource("npm").cached_download

    # The `package.json` stores integrity information about the above passed
    # in `cached_download` npm resource, which breaks `npm -g outdated npm`.
    # This copies back over the vanilla `package.json` to fix this issue.
    cp bootstrap/"package.json", libexec/"lib/node_modules/npm"
    # These symlinks are never used & they've caused issues in the past.
    rm_rf libexec/"share"

    bash_completion.install bootstrap/"lib/utils/completion.sh" => "npm"
  end

  def post_install
    node_modules = HOMEBREW_PREFIX/"lib/node_modules"
    node_modules.mkpath
    # Kill npm but preserve all other modules across node updates/upgrades.
    rm_rf node_modules/"npm"

    cp_r libexec/"lib/node_modules/npm", node_modules
    # This symlink doesn't hop into homebrew_prefix/bin automatically so
    # we make our own. This is a small consequence of our
    # bottle-npm-and-retain-a-private-copy-in-libexec setup
    # All other installs **do** symlink to homebrew_prefix/bin correctly.
    # We ln rather than cp this because doing so mimics npm's normal install.
    ln_sf node_modules/"npm/bin/npm-cli.js", HOMEBREW_PREFIX/"bin/npm"
    ln_sf node_modules/"npm/bin/npx-cli.js", HOMEBREW_PREFIX/"bin/npx"

    # Let's do the manpage dance. It's just a jump to the left.
    # And then a step to the right, with your hand on rm_f.
    %w[man1 man5 man7].each do |man|
      # Dirs must exist first: https://github.com/Homebrew/legacy-homebrew/issues/35969
      mkdir_p HOMEBREW_PREFIX/"share/man/#{man}"
      rm_f Dir[HOMEBREW_PREFIX/"share/man/#{man}/{npm.,npm-,npmrc.,package.json.,npx.}*"]
      cp Dir[libexec/"lib/node_modules/npm/man/#{man}/{npm,package.json,npx}*"], HOMEBREW_PREFIX/"share/man/#{man}"
    end

    (node_modules/"npm/npmrc").atomic_write("prefix = #{HOMEBREW_PREFIX}\n")
  end

  test do
    path = testpath/"test.js"
    path.write "console.log('hello');"

    output = shell_output("#{bin}/node #{path}").strip
    assert_equal "hello", output
    output = shell_output("#{bin}/node -e 'console.log(new Intl.NumberFormat(\"en-EN\").format(1234.56))'").strip
    assert_equal "1,234.56", output

    output = shell_output("#{bin}/node -e 'console.log(new Intl.NumberFormat(\"de-DE\").format(1234.56))'").strip
    assert_equal "1.234,56", output

    # make sure npm can find node
    ENV.prepend_path "PATH", opt_bin
    ENV.delete "NVM_NODEJS_ORG_MIRROR"
    assert_equal which("node"), opt_bin/"node"
    assert_predicate HOMEBREW_PREFIX/"bin/npm", :exist?, "npm must exist"
    assert_predicate HOMEBREW_PREFIX/"bin/npm", :executable?, "npm must be executable"
    npm_args = ["-ddd", "--cache=#{HOMEBREW_CACHE}/npm_cache", "--build-from-source"]
    system "#{HOMEBREW_PREFIX}/bin/npm", *npm_args, "install", "npm@latest"
    system "#{HOMEBREW_PREFIX}/bin/npm", *npm_args, "install", "bufferutil" unless head?
    assert_predicate HOMEBREW_PREFIX/"bin/npx", :exist?, "npx must exist"
    assert_predicate HOMEBREW_PREFIX/"bin/npx", :executable?, "npx must be executable"
    assert_match "< hello >", shell_output("#{HOMEBREW_PREFIX}/bin/npx cowsay hello")
  end
end
