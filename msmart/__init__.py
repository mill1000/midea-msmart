from importlib import metadata

__version__ = metadata.version("msmart-ng")

# Guard against legacy msmart package which may cause conflicts
try:
    metadata.version("msmart")
    raise ImportError("Legacy msmart packaged detected. Please remove.")
except metadata.PackageNotFoundError:
    # Good, legacy package is missing
    pass
