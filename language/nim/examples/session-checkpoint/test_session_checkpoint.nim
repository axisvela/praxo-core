import ./session_checkpoint

let outcome = run()
doAssert outcome.restored == 4, "expected four restored messages"
doAssert outcome.output == "turn 5", "expected the third turn output"
echo "Nim session checkpoint test passed"
