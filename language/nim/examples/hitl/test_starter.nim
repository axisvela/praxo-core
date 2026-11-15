import ./starter

let lines = run()
doAssert lines == @["approve: written; effects=1",
                    "edit: policy rejected; effects=0"]
echo "Nim HITL example test passed"
