// Package conformance provides reusable contract checks for framework seams.
//
// Implementations can call the Check functions from their own tests to verify
// behavior that the interface documentation requires. The checks use only the
// public contracts and do not depend on another implementation.
package conformance
