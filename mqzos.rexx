/* function: Convert output from CSQUTIL to single column data 
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
-- rexx exec to read output file from MQ DISPLAY commands and convert into
-- a file with attribute per line, in format keyword value

parse arg qm out .

if qm  = ""
then call help

parse source platform  . source

If (platform = 'LINUX' ) then erase = 'rm '
else erase = 'ERASE'	

file_line = 0;

outqm = '' -- put out filename.qm at top of the file
inqm = qm
filename = qm
if out = '' then outfile = qm".out"
else outfile = out
say "Reading file:" filename
say "output file:" outfile
kwcount = 0

line=linein(filename,1,0)            -- position file at the start


if lines(filename) = 0
then call errmsg 8 , "Cannot access file:" filename". Check that file exists."

-- remove the output file

if lines(outfile) > 0  then  erase outfile
 

do iLines=1 while lines(filename)         -- while there are more lines to read ...
   -- lines like CSQM408I )MQP1  have queue manager name in the message
   if  (substr(line,1,5)="CSQM4" & outqm = '') then
   do
      parse var line . fileqm .  -- new object
      say "Found queue manager name:"fileqm
      outqm = "!!QM "fileqm
      call lineout outfile,outqm  -- print out !  object type and name
   end;

   line = getLine(filename)           -- read line
   if (substr(line,1,3) = 'CSQ') then iterate ilines

   -- some commands are like QUEUE(ABC) but sub spreads across multiple lines
   -- So we need to build up the line to have start and end brackets
   if  (pos("(",line) <> 0) then
   do while (pos("(",line) <> 0) & (pos(")",line) = 0) -- no closing bracket
            line = line getLine(fileName)              -- append next line
   end

   -- QUEUE(ABC) or PROCESS(MYPROCESS)
   parse var line objNameAtt"(" objName ")" restOfLine
   if (substr(objNameAtt,1,3) = 'DIS') then iterate ilines  -- it is a display command
   -- save the type - we can change otype later
   otype = objNameAtt

   if objNameAtt = "QMNAME" then otype  = 'QMGR'

   oname=strip(objName)

   if objName = "" then iterate ilines

    kwcount =  0      -- pre set this
   do o=1 while lines(filename)
     line = getLine(filename)
      -- some lines are like QUEUE(ABC) but sub spreads across multiple lines
      -- So we need to build up the line to have start and end brackets
      if  (pos("(",line) <> 0) then
      do while (pos("(",line) <> 0) & (pos(")",line) = 0) -- no closing bracket
            line = line getLine(fileName)              -- append next line
      end


     posColon = pos(':',line)  -- distrbuted
     if  posColon > 0 & posColon <   7 then colon = 1  -- either '2  : ' or ' :  '
     else colon = 0

     -------------------------------------
     -- if We have reached the end of an object so output it
     -------------------------------------
     if (left(line,8) = "CSQ9022I",
            | left(line,4) = "CSQM",
            | left(line,2) = 'MQ',    -- eg AMQ8633: Display topic details.
            | colon > 0, -- Distributed new display command
            ) then
     do -- save data
        call lineout outfile,"!"otype oname  -- print out !  object type and name
        -- n
        do ikw = 1 to kwCount
          call lineout outfile,keyword.ikw value.ikw
        end;
        otype = objNameAtt   -- reset process
        iterate ilines;      -- and try the next one
     end -- save data

     if (left(line,8) = "CSQ9022I",   -- z/OS
         | colon > 0, -- Distributed
         ),       --new/end of display?                                                                  s
         then do
            iterate iLines                                 -- new display coming up, find its type
         end
     if left(line,8) = "COMMAND " then iterate ilines      -- not found type message
     if left(line,4) = "CSQU" then iterate ilines      -- utility statement     if left(line,4) = "CSQN" then iterate ilines      -- not found type message
     if left(line,4) = "CSQM" then iterate o      -- new object coming up, find its name - z/OS
     if left(line,2) = "MQ" then iterate o      -- new object coming up, find its name - distributed
     if line =" "           then iterate o      -- new object coming up, find its name - distributed
     -- if there is  a ( in the line we need a matching ) - but it may be on next line
     -- or two eg long comment


     do while (pos("(",line) <> 0) & (pos(")",line) = 0) -- no closing bracket
        line = line getLine(fileName)              -- append next line
     end
     -- handle multiple items on a line

     -- get the keywork(value) or NOSHARE  ...
     parse var line kw  .
     if pos('(',kw) > 0 then
     do
        parse var line name "(" value ")" etc
        if left(etc,1) = ")"  then                    -- special case: parsing drops
        do
           value = value || ")"                    -- second ")" in "conname(host(port))"
           etc = substr(etc,2)                     -- ignore the second ')'
        end

        value = translate(value," ",",")          -- change commas to blanks, eg namelist
     end
     else   -- something like trigger or noshare
     do
        parse var line name  etc
        name = line
        value = line                               -- name is actually the value
        if left(name,2) = "NO" then name = substr(name,3) -- drop "no" from name
     end

    if (name = 'TYPE' & otype <> 'TOPIC')  then
     do
 --      otype = otype'.'value
       otype = value
     end;
     else
     if (name = 'CHLTYPE')  then otype = value
     else
     do
          kwcount = kwcount + 1
          keyword.kwcount = name
          value.kwcount = value
      end

   end -- o=1

end -- iLines=1

 call lineout outfile  -- close the file

return


getLine: procedure expose file_line
parse arg fn
ln = linein(fn)

if ln = "" then return ln
return strip(substr(ln,2))                 -- drop print cc and remove blanks
-------------------


amqobject:
amqmsg = word(line,1)
select
       when amqmsg = 'MQ8408:' then amqobj = 'QMGR'
       when amqmsg = 'MQ8409:' then amqobj = 'QUEUE'

       when amqmsg = 'MQ8633:' then amqobj = 'TOPIC'
       when amqmsg = 'MQ8096:' then amqobj = 'SUB'
       when amqmsg = 'MQ8414:' then amqobj = 'CHANNEL'
       when amqmsg = 'MQ8550:' then amqobj = 'NAMELIST'
       when amqmsg = 'MQ8407:' then amqobj = 'PROCESS'
       when amqmsg = 'MQ8878:' then amqobj = 'CHLAUTH'
       when amqmsg = 'MQ8441:' then amqobj = 'CLUSQMGR'
       when amqmsg = 'MQ8409:' then amqobj = 'QCLUSTER'
       otherwise
       do
         amqobj = ''
         say 'unknown object line ' file_line line
       end
       end
return amqobj


help: procedure
say ""
say "Usage:"
say "       REXX mqzos.rexx defs.in <defs.out>"
say ""
say "Where defs.in is the name of the output from CSQUTIL"
say "If defs.out is not specified the output file is the input file appended with .out"
say "The CSQUTIL output should contains one or more of these DISPLAY statements:"
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
exit



errmsg: procedure
parse arg erc , emsg
say emsg
exit erc
