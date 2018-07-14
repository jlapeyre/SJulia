# Test reading Symata expressions from a file

 ClearTemporary()

# The code defines a function, uses it for a calculation and returns the result
  codefile = J( joinpath(Symata.SYMATA_LANG_TEST_PATH, "symata_code.sj") )
T Get(codefile) == [0, cosfixedpoint]

# This is an Symata implementation of ReplaceRepeated
  codefile = J( joinpath(Symata.SYMATA_LANG_TEST_PATH, "replacerepeated.sj") )
  Get(codefile)
T replacerepeated(x^2 + y^6 , List(x => 2 + a, a => 3)) == 25 + y ^ 6

 ClearAll(codefile, cosfixedpoint,replacerepeated, x,i, y,a)

 ClearTemporary()

 ClearAll(f)

# Create some definitions for f
 f(x_,y_) := x^y
 f(x_Integer) := "Integer"
 f(x_AbstractString) := "String"

# Save the definitions to a temporary file
 file = TempName()
 Save(file,f)

# Clear the definitions for f from memory
 ClearAll(f)
# Test that the definition is gone.
T Head(f(3)) == f

# Read the definitions back from the file and delete the file
 Get(file)
### TODO. check that file is deleted
 DeleteFile(file)

# Test that the defintions are restored
T f(2,3) == 8
T f(2) == "Integer"
T f("dog") == "String"

 ClearAll(f,file,x,y)
