class Postgis < Formula
  desc "Adds support for geographic objects to PostgreSQL"
  homepage "https://postgis.net/"
  url "https://download.osgeo.org/postgis/source/postgis-3.2.3.tar.gz"
  sha256 "1b4d8b5c756e5aba59efbc1833b22efe4d6562778eeca56fa497feb2eb13668c"
  license "GPL-2.0-or-later"
  revision 1

  livecheck do
    url "https://download.osgeo.org/postgis/source/"
    regex(/href=.*?postgis[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_monterey: "a06983fd63c61ac020748b18678f04b59302ddc35eb4160608e6a1b435f67abe"
    sha256 cellar: :any,                 arm64_big_sur:  "cb3078ce4108fd79c74a784af5efe560af1ecf7dce233e64bed3c43955f8ddb5"
    sha256 cellar: :any,                 monterey:       "590081b21ec4cd76b191d9aff741cd94d8f72a1a4f85a65736d31faa2e3f5e1a"
    sha256 cellar: :any,                 big_sur:        "4c85fdb0e082abd0d463a01f6fef3ff01531253be8142ecdf98bb16514481eaf"
    sha256 cellar: :any,                 catalina:       "23dbe8900575689de7e21486dc81de57a9e2a2816c54a316d66b2aa8d6fc7bcb"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "43af7937acac558fc14f721c3b71f3eeb510ab27749b80bb2a0d80448b1bddce"
  end

  head do
    url "https://git.osgeo.org/gitea/postgis/postgis.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "gpp" => :build
  depends_on "pkg-config" => :build
  depends_on "gdal" # for GeoJSON and raster handling
  depends_on "geos"
  depends_on "json-c" # for GeoJSON and raster handling
  depends_on "pcre2"
  depends_on "postgresql@14"
  depends_on "proj"
  depends_on "protobuf-c" # for MVT (map vector tiles) support
  depends_on "sfcgal" # for advanced 2D/3D functions

  on_linux do
    depends_on "gcc"
  end

  fails_with gcc: "5"

  def postgresql
    Formula["postgresql@14"]
  end

  def install
    ENV.deparallelize

    ENV["PG_CONFIG"] = postgresql.opt_bin/"pg_config"

    args = [
      "--with-projdir=#{Formula["proj"].opt_prefix}",
      "--with-jsondir=#{Formula["json-c"].opt_prefix}",
      "--with-pgconfig=#{postgresql.opt_bin}/pg_config",
      "--with-protobufdir=#{Formula["protobuf-c"].opt_bin}",
      # Unfortunately, NLS support causes all kinds of headaches because
      # PostGIS gets all of its compiler flags from the PGXS makefiles. This
      # makes it nigh impossible to tell the buildsystem where our keg-only
      # gettext installations are.
      "--disable-nls",
    ]

    system "./autogen.sh" if build.head?
    system "./configure", *args
    system "make"

    # Install to a staging directory to circumvent the hardcoded install paths
    # set by the PGXS makefiles.
    mkdir "stage"
    system "make", "install", "DESTDIR=#{buildpath}/stage"

    # Some files are stored in the stage directory with the cellar prefix of
    # the version of postgresql used to build postgis.  Since we copy these
    # files into the postgis keg and symlink them to HOMEBREW_PREFIX, postgis
    # only needs to be rebuilt when there is a new major version of postgresql.
    postgresql_prefix = postgresql.prefix.realpath
    postgresql_stage_path = File.join("stage", postgresql_prefix)
    bin.install (buildpath/postgresql_stage_path/"bin").children
    doc.install (buildpath/postgresql_stage_path/"share/doc").children

    stage_path = File.join("stage", HOMEBREW_PREFIX)
    lib.install (buildpath/stage_path/"lib").children
    share.install (buildpath/stage_path/"share").children

    # Extension scripts
    bin.install %w[
      utils/create_undef.pl
      utils/postgis_proc_upgrade.pl
      utils/postgis_restore.pl
      utils/profile_intersects.pl
      utils/test_estimation.pl
      utils/test_geography_estimation.pl
      utils/test_geography_joinestimation.pl
      utils/test_joinestimation.pl
    ]
  end

  test do
    pg_version = postgresql.version.major
    expected = /'PostGIS built for PostgreSQL % cannot be loaded in PostgreSQL %',\s+#{pg_version}\.\d,/
    postgis_version = Formula["postgis"].version.major_minor
    assert_match expected, (share/postgresql.name/"contrib/postgis-#{postgis_version}/postgis.sql").read

    require "base64"
    (testpath/"brew.shp").write ::Base64.decode64 <<~EOS
      AAAnCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAoOgDAAALAAAAAAAAAAAAAAAA
      AAAAAADwPwAAAAAAABBAAAAAAAAAFEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAAAEAAAASCwAAAAAAAAAAAPA/AAAAAAAA8D8AAAAAAAAA
      AAAAAAAAAAAAAAAAAgAAABILAAAAAAAAAAAACEAAAAAAAADwPwAAAAAAAAAA
      AAAAAAAAAAAAAAADAAAAEgsAAAAAAAAAAAAQQAAAAAAAAAhAAAAAAAAAAAAA
      AAAAAAAAAAAAAAQAAAASCwAAAAAAAAAAAABAAAAAAAAAAEAAAAAAAAAAAAAA
      AAAAAAAAAAAABQAAABILAAAAAAAAAAAAAAAAAAAAAAAUQAAAAAAAACJAAAAA
      AAAAAEA=
    EOS
    (testpath/"brew.dbf").write ::Base64.decode64 <<~EOS
      A3IJGgUAAABhAFsAAAAAAAAAAAAAAAAAAAAAAAAAAABGSVJTVF9GTEQAAEMA
      AAAAMgAAAAAAAAAAAAAAAAAAAFNFQ09ORF9GTEQAQwAAAAAoAAAAAAAAAAAA
      AAAAAAAADSBGaXJzdCAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgIFBvaW50ICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgU2Vjb25kICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICBQb2ludCAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgIFRoaXJkICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgUG9pbnQgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICBGb3VydGggICAgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgIFBvaW50ICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgQXBwZW5kZWQgICAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAgICAgICBQb2ludCAgICAgICAgICAgICAgICAgICAgICAg
      ICAgICAgICAgICAg
    EOS
    (testpath/"brew.shx").write ::Base64.decode64 <<~EOS
      AAAnCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARugDAAALAAAAAAAAAAAAAAAA
      AAAAAADwPwAAAAAAABBAAAAAAAAAFEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
      AAAAAAAAAAAAAAAAADIAAAASAAAASAAAABIAAABeAAAAEgAAAHQAAAASAAAA
      igAAABI=
    EOS
    result = shell_output("#{bin}/shp2pgsql #{testpath}/brew.shp")
    assert_match "Point", result
    assert_match "AddGeometryColumn", result

    pg_ctl = postgresql.opt_bin/"pg_ctl"
    psql = postgresql.opt_bin/"psql"
    port = free_port

    system pg_ctl, "initdb", "-D", testpath/"test"
    (testpath/"test/postgresql.conf").write <<~EOS, mode: "a+"

      shared_preload_libraries = 'postgis-3'
      port = #{port}
    EOS
    system pg_ctl, "start", "-D", testpath/"test", "-l", testpath/"log"
    system psql, "-p", port.to_s, "-c", "CREATE EXTENSION \"postgis\";", "postgres"
    system pg_ctl, "stop", "-D", testpath/"test"
  end
end
