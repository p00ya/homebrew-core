class Numpy < Formula
  desc "Package for scientific computing with Python"
  homepage "https://www.numpy.org/"
  url "https://files.pythonhosted.org/packages/f2/a5/fdbf6a7871703df6160b5cf3dd774074b086d278172285c52c2758b76305/numpy-2.2.1.tar.gz"
  sha256 "45681fd7128c8ad1c379f0ca0776a8b0c6583d2f69889ddac01559dfe4390918"
  license "BSD-3-Clause"
  head "https://github.com/numpy/numpy.git", branch: "main"

  MKLROOT = "/opt/intel/mkl".freeze

  bottle do
    sha256 cellar: :any,                 arm64_sequoia: "3cfd91496af13d62ad8e2a84efe4267196ff2f872b59c66313e4741593676872"
    sha256 cellar: :any,                 arm64_sonoma:  "d4530f16d45d6baf5c6c1f7fe86690e05e47c11c5cdfcb02e4b7c85027dadb83"
    sha256 cellar: :any,                 arm64_ventura: "927a4cefdea10dbb612908c19711c8916cc2b34d8d2d4ae8b4383c0ed0a5f010"
    sha256 cellar: :any,                 sonoma:        "eb494266ed71b7bedd3be7760f161b889d77f6254461dd14316b3a45a1aacd19"
    sha256 cellar: :any,                 ventura:       "e38508170528b7b28e909e6dcc8cd91ca44679aefc8b0ac9e715b27eaa9e9d2d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "e8b745e86107009664d5a73a9df9655f4028d1d278ae17778c3a6168d984b1d4"
  end

  depends_on "gcc" => :build # for gfortran
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "python@3.12" => [:build, :test]
  depends_on "python@3.13" => [:build, :test]
  depends_on "openblas"

  on_linux do
    depends_on "patchelf" => :build
  end

  def pythons
    deps.map(&:to_formula)
        .select { |f| f.name.start_with?("python@") }
        .sort_by(&:version) # so scripts like `bin/f2py` use newest python
  end

  def install
    # See also:
    # https://software.intel.com/en-us/articles/numpyscipy-with-intel-mkl
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "#{MacOS.version}"
    ENV.append_to_cflags "-march=native"
    ENV.append_to_cflags "-mtune=native"
    ENV.append_to_cflags "-Ofast"
    ENV.append "FCFLAGS", "-Ofast"
    ENV.append "FCFLAGS", "-fexternal-blas"

    ENV["ATLAS"] = "None" # avoid linking against Accelerate.framework
    ENV["BLAS"] = "#{MKLROOT}/lib/libmkl_blas95_ilp64.a"
    ENV["LAPACK"] = "#{MKLROOT}/lib/libmkl_lapack95_ilp64.a"
    config = mkl_config()

    Pathname("site.cfg").write config

    pythons.each do |python|
      python3 = python.opt_libexec/"bin/python"
      system python3, "-m", "pip", "install",
          *std_pip_args(build_isolation: true), "."
    end
  end

  def mkl_config
    return <<~EOS
      [ALL]
      extra_compile_args = -march=native -Ofast

      [mkl]
      library_dirs = #{MKLROOT}/lib
      include_dirs = #{MKLROOT}/include
      rpath = #{MKLROOT}/lib
      mkl_libs = mkl_rt
      lapack_libs =
    EOS
  end

  def openblas_config
    return <<~EOS
      [openblas]
      libraries = openblas
      library_dirs = #{openblas}/lib
      include_dirs = #{openblas}/include  end
    EOS
  end

  def caveats
    <<~EOS
      To run `f2py`, you may need to `brew install #{pythons.last}`
      
      You must export DYLD_LIBRARY_PATH=#{MKLROOT}/lib
      before loading numpy in order to avoid errors like
      "Library not loaded: @rpath/libmkl_rt.dylib".
    EOS
  end

  test do
    pythons.each do |python|
      python3 = python.opt_libexec/"bin/python"
      system python3, "-c", <<~PYTHON
        import numpy as np
        t = np.ones((3,3), int)
        assert t.sum() == 9
        assert np.dot(t, t).sum() == 27
      PYTHON
    end
  end
end
