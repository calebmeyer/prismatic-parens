// Delimiters in comments should not be highlighted
// {} () []
/*
Delimiters in multi-line comments should not be highlighted
{} () []
{
)
*/
arr = [1, 2, 3]

function getRelativeFilePath(filePath, configPath) {
  if (configPath) {
    return relative(dirname(configPath), filePath);
  }
  return filePath;
}

`interpolated ${string}`

// super nested
if(a) {
  if(b) {
    if(c) {
      if(d) {
        if(e) {
          if(f) {
            if(g) {
              if(h) { (
                console.log(i);
              }
            }
          }
        }
      }
    }
  }
}

// unclosed
{[

// unopened
))
