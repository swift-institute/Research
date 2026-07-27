# Canonical package topology and the workspace resolve gate

The local directory basename is part of SwiftPM package identity when a package is
overridden by path. Renaming the physical checkout therefore has to move every live
workspace container path and mirror destination together, while leaving historical
names and public product/module surfaces intact.

The final integration attempt also exposed a separate coordinator boundary: an Xcode
package-resolution command that supplies `-workspace` must carry the selected scheme.
Otherwise Xcode exits during argument validation, before dependency resolution or
compilation, so that failure cannot validate the repaired package graph.
