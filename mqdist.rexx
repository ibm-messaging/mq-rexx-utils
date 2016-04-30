/* Function: Take output from runmqsc command and convert into singe column format
 *
 * Copyright (c) 2016 IBM Corporation and other Contributors.
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Colin Paice- Initial Contribution
 *   Sharuff Morsa - original code
 *   Emir Garza  - original code
 */

parse arg filename outfile .


if filename  = ""
then call help

parse source platform  . source

If (platform = 'LINUX' ) then erase = 'rm '
else erase = 'ERASE'	


file_line = 0;
nextline = ''


outqm = '' -- put out filename.infile at top of the file

say "Reading file:" filename
if outfile = '' then outfile = filename||'.out'
Say "output file:" outfile
if lines(filename) = 0
 then call errmsg 8 , "Cannot access file:" filename". Check that file exists."

line= linein(filename);  -- eg  5724-H72 (C) Copyright IBM Corp. 1994, 2011.  ALL RIGHTS RESERVED.
if substr(line,1,4) <> '5724' then
do;
   say 'file not in correct format'
   return 8;
end;

line= linein(filename);
-- second line Starting MQSC for queue manager colin.
parse var line 'Starting' . . . . qmgr'.'
if (qmgr = '' ) then
do;
   say 'file not in correct format'
   return 8;
end;
kwcount = 0

-- remove the output file
if lines(outfile) > 0  then  erase outfile
call lineout outfile -- as lines... opens handle

call lineout outfile,"!!QM" qmgr
do iLines=1 while lines(filename)         -- while there are more lines to read ...
   if (  ilines//1000 = 0) then say 'processing record number:' ilines
   line = getLine(filename)           -- read line
   if ( word(line,1) = 'Starting') then  -- we have multiple defintions in the file
   do
     say 'Multiple definitions in one file '
     parse var line 'Starting' . . . . qmgr'.'
      if (qmgr = '' ) then
      do;
        say 'file not in correct format: expecting Starting... with qmgr'
        return 8;
      end;
      iterate iLines
   end
   if (substr(line,1,3) = 'AMQ'||substr(line,1,3='All')) then
   do
    -- savedata()
    -- object = amqobject()
    -- otype = object
    --  if ( obtype = 'QMGR' ) then oname  = qmgr
     line = getLine(filename)           -- read line
     parse var line otype"(" oName ")" restOfLine
     line = getLine(filename)           -- read line
     parse var line otype2"(" oName2 ")" restOfLine

     if (otype ='QMNAME')  then otype='QMGR '
     else
          if (otype ='QUEUE')  then
     do;
        otype = oname2
        line = getLine(filename)           -- read line
     end
     else if (otype ='CHANNEL') then
     do;
        otype = oname2
        line = getLine(filename)           -- read line
     end
     call lineout outfile,"!"otype oname  -- print out !  object type and name
   end;

   -- some commands are like QUEUE(ABC) but sub spreads across multiple lines
   -- So we need to build up the line to have start and end brackets
     -- if there is  a ( in the line we need a matching ) - but it may be on next line
     -- or two eg long comment
   if  (pos("(",line) <> 0) then
   do while (pos("(",line) <> 0) & (pos(")",line) = 0) --  while no closing bracket
            line = line getLine(fileName)              -- append next line
   end
     -- get the keywork(value) or NOSHARE  ...
     parse var line kw  .
     if pos('(',kw) > 0 then
     do
        parse var line name "(" value ")" .
        if left(etc,1) = ")"  then                    -- special case: parsing drops
        do
           value = value || ")"                    -- second ")" in "conname(host(port))"
        --  etc = substr(etc,2)                     -- ignore the second ')'
        end

        value = translate(value," ",",")          -- change commas to blanks, eg namelist
     end
     else   -- something like trigger or noshare
     do
        parse var line name . etc
        name = line
        value = line                               -- name is actually the value
        if left(name,2) = "NO" then name = substr(name,3) -- drop "no" from name
     end
     call lineout outfile,name value

end -- iLines=1

 call lineout outfile  -- close the file

return


help: procedure
say ""
say "Usage:"
say "       REXX dist input < output > "
say ""
say "Takes the output from the runmqsc command reformats into into Outfile "
say "The data is converted from 2 columns to 1 column"
say ""
say "The output from runmqsc should contains one or more of these DISPLAY statements:"
say "   DIS QMGR ALL"
say "   DIS Q(*) ALL"
say "   DIS CHL(*) ALL"
say "   DIS NAMELIST(*) ALL"
say "   DIS PROCESS(*) ALL"
say "   DIS STGCLASS(*) ALL"
say "   DIS SUB(*) ALL"
say "   DIS TOPIC(*) ALL"
say "   DIS CLUSQMGR(*) ALL"
say "   DIS CHLAUTH(*) ALL"
say ""

exit



errmsg: procedure
parse arg erc , emsg
say emsg
exit erc


getLine: procedure expose nextline
parse arg fn
if nextline <> '' then
do;
  temp =   strip(nextline)
  nextline = '' -- reset for next time
  return temp;
end;

do iLines=1 while lines(fn)         -- while there are more lines to read ...
 line= linein(fn);

   -- typical data lines
   --      1 :  DISPLAY TOPIC(*) ALL
   -- AMQ8633: Display topic details.
   --    TOPIC(SYSTEM.BASE.TOPIC)                TYPE(LOCAL)
   --    TOPICSTR()

    if line = "" then iterate
    if substr(line,1,3) = 'AMQ' then return line
    if substr(line,1,8) ='Starting' then return line
    -- ignore One MQSC command read.
    -- No commands have a syntax error.
    -- All valid MQSC commands were processed.
    if (substr(line,1,3) <> '   ' ) then iterate -- ignore

    if (substr(line,8,1) = ':') then iterate
    -- mq data is in cols 3 to the end so any other command
    -- is command processing and indicates end of line
  --  if left(line,1) <> ' ' then
  -- do
  --   return line
  --  end;
    if left(line,4) = '    ' then   -- eg  1 :  DISPLAY TOPIC(*) ALL
    do
    return line
     -- iterate ilines
    end;
    else if substr(line,1,3) = 'AMQ' then
    do
     return line

    end
    else if substr(line,1,2) <> '  '    -- eg No commands have a syntax error.
    then iterate ilines
   --                      Col 41 !
  -- we now have some valid data it can be
  -- keyword(value)              Keyword(value)
  -- keyword(value)            	
  -- keywork(value
  -- ...
  -- ..)
  -- keyword                     keyword(value)
  -- keyword
  -- keyword                     keyword
  --                      Col 41 !


  bra = pos('(',line)
  if (bra = 0) then -- kw      kw,  or kw
  do
    if substr(line,44,1)  <> ' ' then nextline = substr(line1,44)  -- second column
    return substr(line1,43)  -- not found
  end
  else
  if (bra > 44 )then  -- not in first column so it is kw ...  kw(value)
  do  -- bra > 44 so not in first column
       nextline = substr(line1,44)  -- second column
       return  strip(substr(line,4,40))  -- eg SHARE
     end
  else
-- we have  a ( in first column) up to 43 - could be a long line
-- may be column 1 and column 2
  do -- we have  a ( in 1-43
    endbra = pos(')',line)
    if ( endbra = 0) then  -- not found
    -- so could be a namelist or other long object
    do  -- ) not found so could be a long list
    --  call lineout out_file , line
       do ij = 1 by 1
         line2= linein(fn)
         line = line ||line2
         if pos(')',line2) > 0 then return line
       end
    end
    else
    if (endbra < 44) then
    do  -- kw(value)    something, or kw(value
      if substr(line,44,1)  <> ' ' then nextline =substr(line,44)  -- second column
      return  strip( substr(line,4,40)) -- first column
    end
    else -- (endbra >= 44) so it is a long line
      return strip(line)
   end


end -- iLines=1
Say 'end of file reached'
return  ''
