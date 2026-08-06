{
  lib,
  stdenv,
  buildPythonPackage,
  fetchFromGitHub,
  cmake,
  setuptools,
  setuptools-scm,
  numpy,
  requests,
  tqdm,
  platformdirs,
  # AMD hardware here; whisper.cpp runs on CPU via GGML_NATIVE=OFF below
  cudaSupport ? false,
  cudaPackages ? { },
  cudaCapabilities ? [ "8.9" ],
  autoAddDriverRunpath,
}:
(buildPythonPackage.override {
  stdenv = if cudaSupport then cudaPackages.backendStdenv else stdenv;
})
  {
    pname = "pywhispercpp";
    version = "1.5.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "absadiki";
      repo = "pywhispercpp";
      tag = "v1.5.0";
      fetchSubmodules = true;
      hash = "sha256-sya7mAz8hrLarS+lqe+ObHN/boahJb3pfwDaWU0+ZlM=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail '"ninja",' "" \
        --replace-fail '"cmake>=3.12",' "" \
        --replace-fail '"repairwheel",' ""
    '';

    build-system = [
      setuptools
      setuptools-scm
    ];

    nativeBuildInputs = [
      cmake
    ]
    ++ lib.optionals cudaSupport [
      cudaPackages.cuda_nvcc
      autoAddDriverRunpath
    ];

    buildInputs = lib.optionals cudaSupport [
      (cudaPackages.cccl or cudaPackages.cuda_cccl)
      cudaPackages.cuda_cudart
      cudaPackages.libcublas
    ];

    dependencies = [
      numpy
      requests
      tqdm
      platformdirs
    ];

    dontUseCmakeConfigure = true;

    env = {
      NO_REPAIR = "1";
      SETUPTOOLS_SCM_PRETEND_VERSION = "1.5.0";
      CMAKE_INSTALL_RPATH = "$ORIGIN";
      CMAKE_BUILD_WITH_INSTALL_RPATH = "ON";
      GGML_NATIVE = "OFF";
    }
    // lib.optionalAttrs cudaSupport {
      GGML_CUDA = "1";
      CMAKE_CUDA_ARCHITECTURES = lib.concatStringsSep ";" (
        map (c: lib.replaceStrings [ "." ] [ "" ] c) cudaCapabilities
      );
    };

    preBuild = ''
      export CMAKE_BUILD_PARALLEL_LEVEL=$NIX_BUILD_CORES
    '';

    pythonImportsCheck = [ "pywhispercpp" ];

    meta = {
      description = "Python bindings for whisper.cpp";
      homepage = "https://github.com/absadiki/pywhispercpp";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  }
