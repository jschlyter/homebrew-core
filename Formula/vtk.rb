class Vtk < Formula
  desc "Toolkit for 3D computer graphics, image processing, and visualization"
  homepage "https://www.vtk.org/"
  url "https://www.vtk.org/files/release/8.1/VTK-8.1.1.tar.gz"
  sha256 "71a09b4340f0a9c58559fe946dc745ab68a866cf20636a41d97b6046cb736324"
  revision 1
  head "https://github.com/Kitware/VTK.git"

  bottle do
    sha256 "a3e2898884b2b0f7901bb94cae76fc43cc578ad48eb1a214eb4bfb585c32f4b4" => :high_sierra
    sha256 "b3c1352797f5a0c7eca2b84710797161156730930bcdd67af3aa984644a48602" => :sierra
    sha256 "f56d03fcbb8d26afa1e0ed7f92f80de0306cb39f9c2c377e48dabea918e257ab" => :el_capitan
  end

  option "without-python@2", "Build without python2 support"

  deprecated_option "without-python" => "without-python@2"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "fontconfig"
  depends_on "hdf5"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "netcdf"
  depends_on "python@2" => :recommended
  depends_on "python" => :optional
  depends_on "qt" => :optional
  depends_on "pyqt" if build.with? "qt"

  needs :cxx11

  def install
    args = std_cmake_args + %W[
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
      -DCMAKE_INSTALL_NAME_DIR:STRING=#{lib}
      -DCMAKE_INSTALL_RPATH:STRING=#{lib}
      -DModule_vtkInfovisBoost=ON
      -DModule_vtkInfovisBoostGraphAlgorithms=ON
      -DModule_vtkRenderingFreeTypeFontConfig=ON
      -DVTK_REQUIRED_OBJCXX_FLAGS=''
      -DVTK_USE_COCOA=ON
      -DVTK_USE_SYSTEM_EXPAT=ON
      -DVTK_USE_SYSTEM_HDF5=ON
      -DVTK_USE_SYSTEM_JPEG=ON
      -DVTK_USE_SYSTEM_LIBXML2=ON
      -DVTK_USE_SYSTEM_NETCDF=ON
      -DVTK_USE_SYSTEM_PNG=ON
      -DVTK_USE_SYSTEM_TIFF=ON
      -DVTK_USE_SYSTEM_ZLIB=ON
      -DVTK_WRAP_TCL=ON
    ]

    unless MacOS::CLT.installed?
      # We are facing an Xcode-only installation, and we have to keep
      # vtk from using its internal Tk headers (that differ from OSX's).
      args << "-DTK_INCLUDE_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers"
      args << "-DTK_INTERNAL_PATH:PATH=#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Headers/tk-private"
    end

    mkdir "build" do
      if build.with?("python") && build.with?("python@2")
        # VTK Does not support building both python 2 and 3 versions
        odie "VTK: Does not support building both python 2 and 3 wrappers"
      elsif build.with?("python") || build.with?("python@2")
        python_executable = `which python3`.strip if build.with? "python"
        python_executable = `which python2.7`.strip if build.with? "python@2"

        python_prefix = `#{python_executable} -c 'import sys;print(sys.prefix)'`.chomp
        python_include = `#{python_executable} -c 'from distutils import sysconfig;print(sysconfig.get_python_inc(True))'`.chomp
        python_version = "python" + `#{python_executable} -c 'import sys;print(sys.version[:3])'`.chomp
        py_site_packages = "#{lib}/#{python_version}/site-packages"

        args << "-DVTK_WRAP_PYTHON=ON"
        args << "-DPYTHON_EXECUTABLE='#{python_executable}'"
        args << "-DPYTHON_INCLUDE_DIR='#{python_include}'"
        # CMake picks up the system's python dylib, even if we have a brewed one.
        if File.exist? "#{python_prefix}/Python"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/Python'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.a"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.a'"
        elsif File.exist? "#{python_prefix}/lib/lib#{python_version}.dylib"
          args << "-DPYTHON_LIBRARY='#{python_prefix}/lib/lib#{python_version}.dylib'"
        else
          odie "No libpythonX.Y.{dylib|a} file found!"
        end
        # Set the prefix for the python bindings to the Cellar
        args << "-DVTK_INSTALL_PYTHON_MODULE_DIR='#{py_site_packages}/'"
      end

      if build.with? "qt"
        args << "-DVTK_QT_VERSION:STRING=5" << "-DVTK_Group_Qt=ON"
        args << "-DVTK_WRAP_PYTHON_SIP=ON"
        args << "-DSIP_PYQT_DIR='#{Formula["pyqt5"].opt_share}/sip'"
      end

      system "cmake", "..", *args
      system "make"
      system "make", "install"
    end

    # Avoid hard-coding Python 2 or 3's Cellar paths
    inreplace Dir["#{lib}/cmake/**/vtkPython.cmake"].first do |s|
      if build.with? "python"
        s.gsub! Formula["python"].prefix.realpath, Formula["python"].opt_prefix
      end
      if build.with? "python@2"
        s.gsub! Formula["python@2"].prefix.realpath, Formula["python@2"].opt_prefix
      end
    end

    # Avoid hard-coding HDF5's Cellar path
    inreplace Dir["#{lib}/cmake/**/vtkhdf5.cmake"].first,
      Formula["hdf5"].prefix.realpath, Formula["hdf5"].opt_prefix
  end

  def caveats; <<~EOS
    Even without the --with-qt option, you can display native VTK render windows
    from python. Alternatively, you can integrate the RenderWindowInteractor
    in PyQt5, Tk or Wx at runtime. Read more:
      import vtk.qt5; help(vtk.qt5) or import vtk.wx; help(vtk.wx)
  EOS
  end

  test do
    vtk_include = Dir[opt_include/"vtk-*"].first
    major, minor = vtk_include.match(/.*-(.*)$/)[1].split(".")

    (testpath/"version.cpp").write <<~EOS
      #include <vtkVersion.h>
      #include <assert.h>
      int main(int, char *[]) {
        assert (vtkVersion::GetVTKMajorVersion()==#{major});
        assert (vtkVersion::GetVTKMinorVersion()==#{minor});
        return EXIT_SUCCESS;
      }
    EOS

    system ENV.cxx, "-std=c++11", "version.cpp", "-I#{vtk_include}"
    system "./a.out"
    system "#{bin}/vtkpython", "-c", "exit()"
  end
end
