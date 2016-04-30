/*
 * Function: take the name1 name2   , read the files name1.out name2.out and generate HTML of differences
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

parse source platform  . source

If (platform = 'LINUX' ) then erase = 'rm '
else erase = 'ERASE'	


If (platform = 'LINUX' ) then pSlash = lastpos('/',source)
else  pSlash = lastpos('\',source)
if pSlash > 0 then basepath=substr(source,1,pSlash)
else basepath = ''
ignorefile = basepath||'ignore.list'

parse arg inputFileNames
if inputFileNames = "" | inputFileNames = "?"
then call help

ignore. = 0
ignoreall.  = 0
DoIgnores()

varlist. = ""
namelist. = ""

objtypes = "QMGR QLOCAL QALIAS QMODEL QREMOTE QCLUSTER CLUSQMGR  NAMELIST TOPIC SUB   STGCLASS PROCESS CHLAUTH"

qmgr. = "missing"                     -- array to store attribute values
exists. = 0                    -- array to note if an object is defined to a queue manager

qmgrs =  ''      -- list of queuem managers found

startMenu = 'aStart.html'
DateTime =  date() time()    -- display time in the output panels

-- remove the old output files

if lines(startMenu) > 0 then 
erase   startMenu
call lineout startMenu

 -- for each name in the input list read the file
do jqmgrs=1 to words(inputFileNames)
  fn = word(inputFileNames,jqmgrs)
  call readFile fn
end

-- put the boiler plate at the top of each file
types = objtypes
do i = 1 to words(types)
  w= word(types,i)
  of = w||'_detail.html'
  if lines(of) > 0  then
  erase of
  call lineout of
  call lineout of
  call lineout of, "<!DOCTYPE html><html>"
  call lineout of,  "<body>"
  call lineout of, "<h1>Created on "dateTime"</h1>"
  diff = w||'_difference.html'
  if lines(diff) > 0  then
  erase diff
  call lineout diff
  call lineout diff
  call lineout diff, "<!DOCTYPE html><html>"
  call lineout diff,  "<body>"
end


---------------------------------------------------------------
--  Now create the output files
---------------------------------------------------------------

-- Create the start menu
say "Writing file:"  startMenu
call lineout startMenu, '<!DOCTYPE html><html>'
call lineout startMenu, '<body>'
call lineout startMenu, '<h1> Data processed on 'DateTime'</h1>'
call lineout startMenu, "<TABLE BORDER=4 CELLSPACING=4 CELLPADDING=4>"
call lineout startMenu, "<TR>"
call lineout startMenu, "<TD>Summary of objects</td><td>all attributes</td><td>differences</td>"
call lineout startMenu, "</TR>"



do iTypes=1 to words(types);   -- qmgr qr etc
   objType = word(types,iTypes);
   outfile= objType||'.html'
   if lines(outfile) > 0  then
   erase outfile    -- the   objType||'.html'
   call lineout outfile 
   if  words(namelist.objType)  = 0 then
   Do
     iterate iTypes -- nothing to display
   end
   say "Writing file:" outfile
   call lineout startMenu , "<TR>"
   call lineout startMenu , '<TD><a href="./'objType'.html">'objType'</a></td>'              -- eg QLOCAL
   call lineout startMenu , '<TD><a href="./'objType'_detail.html">All details</a></td>'     -- Clickable
   call lineout startMenu , '<TD><a href="./'objType'_difference.html">Differences</a></td>' -- Clickable
   call lineout startMenu , "</TR>"

   openhtml(outfile)     -- common routine

   -- put out the name of the entirty
   call lineout outfile , startTH(objtype)||objtype||endTH(objtype)
   -- create the column header with the queue manager names
   -- so loop for each queue manager
   do i=1 to words(qmgrs)
     qm = word(qmgrs,i)
     call lineout outfile , "<TH>"qm"</thd>"
   end


   -- the end of the table header row
   call lineout outfile , "</TR>"

   -- do for each queue, qr  list of object s
   -- do each item in the list in turn
   do iobjectnames=1 to words(namelist.objType) -- names of queues etc
      if (iobjectnames//1000 = 0) then say 'processing record number:' iobjectnames
      doneHeader= 0                             -- for when there are mismatches
      objectDifference = 0;                     -- for when there are mismatches
      objName = word(namelist.objType, iobjectnames)  -- get the name of the object

      outfileDiff = objtype||'_difference.html' -- the differences file name
      outfileDetail = objtype||'_detail.html'   -- all the information
      doSection(outfileDetail)                  -- put out all the data

      do iqm=1 to words(qmgrs)
        diff.iqm = 0  -- reset these
      end

      -- go through each attribute in turn and print them out

      -- compare with the first queue manager and report if the data is different
      -- find first valid queue manager for this object.
      -- for example the first queue manager is MQA, second is MQB, third is MQ3
      -- this object does not exist for MQA, but does exist for MQB and MQC
      -- so use MQA is empty ( does not exist)
      -- MQB is then used as the master object so object on MQC is compare with MQB's
      do jqm=1 to words(qmgrs)
          jqmw = word(qmgrs,jqm)
          if exists.jqmw.objType.objName = 0 then iterate jqm
          qm1 = jqmw   -- Weve found the first queue manager with this object ( eg MQB)
          leave
      end
      -- varlist.objtype contains all of the attributes such as DESCR and ALTTIME
      -- We need to go through each one turn.
      -- some queue managers may not have all of the attributes
      -- so we need to handle this as well
      do iattribute=1 to words(varlist.objType) -- attributes
        name = word(varlist.objType, iattribute)
        -- display the attribute name
        call lineout outfileDetail , '<TR>'
        call lineout outfileDetail , ' <TD >'name'</td>'
        difference = 0
        outline = ''  -- we build up the output line in this variable
        -- now do each queue manager in turn and write out the data in its column
        outdiff = ''
        do iqm=1 to words(qmgrs)
         
          qm = word(qmgrs,iqm)
          if exists.qm.objType.objName = 0 then  -- eg MQA in comment above
          do
            outline= outline ||' <TD BGCOLOR="#FFFF00">Object not defined</td>'
            -- record this as a difference
            diff.iqm = diff.iqm + 1      -- for summary
            iterate iqm
          end

          -- now compare the value with the first valid queue manager with the object
          value  = QMGR.qm.objType.objName.name
          value1 = QMGR.qm1.objType.objName.name
          if outdiff = '' then outdiff = "<tr><td>"name"</td><td>"qm"</td><td>"value1"</td></TR>"
          -- if they match display the value then display in normal text
          -- but  ignore altdate and altime etc
            if (value1 = value,
                  | ignoreall.name = 1,
                  | ignore.objtype.name = 1,
                 ) then

            do;
             outline = outline||startTD(value)||value||endTD(value)
            end
            -- say id didnt match and record there is a difference
            else
            do
               outline = outline||startTD(value,'BGCOLOR="#00FF22"')||value||endTD(value)
               outdiff = outdiff ||  '<tr><td>'name'</td><td>'qm'</td><td BGCOLOR="#FFFF00">'value'</TD></TR>'
               difference = difference + 1
               diff.iqm = diff.iqm + 1
            end
          end -- iqm  -- each queue manager
          -- create column 2 being the number of differences in between queue managers
        if difference = 0 then
          outline = '<TD >'difference'</td>' outline  -- comes out as 0
        else  outline = '<TD >!!'difference'</td>' outline -- comes out such as !!1
        -- this allows you to search for !! and find the differences

        call lineout outfileDetail, outline   -- write line to file
        call lineout outfileDetail, '</tr>'    -- and end of row
        -- if we need to write to the differences file then do it now
        -- if this is the first entry for this object we need to put out the header
        -- and table definition
        if difference > 0 then
        Do
           if (doneHeader= 0) then   -- we havent done it
           do;
       --      doSection( outfileDiff) -- go do it
             doDiffHeader( outfileDiff) -- go do it
                                                      doneHeader=1            -- say we have done it
           End;
           -- start a new new
           call lineout outfileDiff , '<TR>'
           -- put out the attrbute name
        --  call lineout outfileDiff , ' <TD >'name'</td>'
           -- and the data from the queue managers
        --   call lineout outfileDiff, outdiff    -- write line to file
           pstart = 1
           p = pos("</TR>",outdiff,pstart)
           do while(p > 0)
               part= substr(outdiff,pstart,p+5  -pstart ) -- length of  </td>
               call lineout outfileDiff, part   -- write line to file
               pstart = p+5
               p = pos("</TR>",outdiff,pstart)
           end;
        --  call lineout outfileDiff, outline   -- write line to file
           call lineout outfileDiff, '</tr>'    -- and end of row
        End;
        if ( difference > 0 ) then
        ObjectDifference = ObjectDifference + 1;  -- number of attribuetes different
      end -- iattribute

      call lineout outfileDetail ,'</TABLE>'
      if ( doneHeader= 1) then   -- if we wrote the header we need to write the trailer
         call lineout outfileDiff   ,'</TABLE>'


       -- now the summary file
      summary = ''
      -- for each queue manager
      do iqm=1 to words(qmgrs)
         qm = word(qmgrs,iqm)
        if exists.qm.objType.objName = 0 then
             summary= summary ||'<TD BGCOLOR="#FFFF00">Not defined</td>'

        else if diff.iqm = 0 then  -- no differences between this and the first/master
                if qm = qm1 then summary= summary ||' <TD><a href="./'outfileDetail'#'objname'">'OK'</a> </td>'  -- for first queue manager
                else summary= summary ||' <TD >=</td>' -- all of the rest  say it is the same
        else summary= summary ||' <TD BGCOLOR="#00FF00"><a href="./'outfileDiff'#'objname'">mixed</a></td>'  -- display it coloured
        diff.imq = 0 -- reset for next time
      end
      call lineout outfile ,'</TR>'
      --  specify the attribute, as a link to the difference
      if (ObjectDifference >  0)  then
      Do;
        call lineout outfile , startTD(objname)||'<a href="./'outfileDiff'#'objname'">'objname'</a>'endTD(objname)
      end;
      else -- just display it with no link                                                                                                                   	
        call lineout outfile , startTD(objname)||objname||endTD(objname)	

      call lineout outfile , summary -- write out the queue manager stuff
      call lineout outfile ,'</TR>' -- and the end of row
   end -- iobjectnames

-- close the table and save the file
   closehtml(outfile)

end -- iTypes

-- put out the trailer infor
do i = 1 to words(types)
  w= word(types,i)
  of = w||'_detail.html'
  call lineout of, "</html>"
end
call lineout startMenu ,"</table></html>"

exit
--------------------------------------------
-- READFILE
--------------------------------------------

readFile:

inqm = fn
qm = fn
filename = fn
say "Reading file:" filename

line=linein(filename,1,0)            -- position file at the start

if lines(filename) = 0   -- no records
then call errmsg 8 , "Cannot access file:" filename". Check that file exists."

line = linein(filename)           -- read line
if (word(line,1) = "!!QM") then fileqm = word(line,2)
else
do;
  say "expecting !!QM name  as the first line"
  exit 8
End;
qm = fn'.'fileqm
qmgrs = qmgrs qm; -- save the name of the queue manager file
xx = 0
do iLines=1 while lines(filename)         -- while there are more lines to read ...
   if ( ilines // 10000  = 0 ) then say "reading line:" ilines
   line = linein(filename)           -- read line
   if ( substr(line,1,1) = "!") then
   do;
     parse var line "!"object name

     if wordpos(object,objtypes  ) = 0 then objtypes   = objtypes   object
     if ( object = 'QMGR') then
     do;
       --   if wordpos('QMGR', namelist.object) = 0 then namelist.object = namelist.object 'QMGR'
       name = 'QMGR'
     end;
  --  else
     
     if wordpos(name, namelist.object) = 0 then namelist.object = namelist.object name

     exists.qm.object.name = 1
     iterate ilines
   end;
   parse var line kw value
   value = strip(value)
   if wordpos(kw,varlist.object) = 0  then varlist.object = varlist.object kw
   QMGR.qm.object.name.kw = value             -- eg mqpa qlocal descr

end -- iLines=1

return


help: procedure
say ""
say "Usage:"
say "       REXX tohtml name1 name2 etc"
say ""
say "Where <name1 name2 ... > is a list of pre-processsed files"
say " From the processed  z/OS CSQUTIL output   "
say " or the processed output from runmqsc command"  
say "The MQ commands should contains one or more of these DISPLAY statements:"
say "   DIS QMGR ALL"
say "   DIS Q(*) ALL"
say "   DIS CHL(*) ALL"
say "   DIS NAMELIST(*) ALL"
say "   DIS PROCESS(*) ALL"
say "   DIS STGCLASS(*) ALL"
say "   DIS SUB(*) ALL"
say "   DIS TOPIC(*) ALL"
say "   DIS CLUSQMGR(*) ALL"

say ""

exit
---------------------------------------------------------
startTD: procedure

parse arg TDarg,style
if length(TDArg) < 48 then return "<TD "style">"
else  return '<td '||style||' width="600"><div style="width: 600px;overflow: auto">'

endTD: procedure
parse arg TDarg
if length(TDArg) < 48 then return "</TD >"
else return '</div></td>'

startTH: procedure

parse arg TDarg,style
if length(TDArg) < 48 then return "<TH "style">"
else  return '<th '||style||' width="400"><div style="width: 400px;overflow: auto">'

endTH: procedure
parse arg TDarg
if length(TDArg) < 48 then return "</TH >"
else return '</div></th>'


errmsg: procedure
parse arg erc , emsg
say emsg
exit erc

openhtml: procedure  expose DateTime
 parse arg fn
   call lineout fn , "<!DOCTYPE html><html>"
   call lineout fn , "<body>"
   call lineout fn, '<h1> Data processed 'DateTime'</h1>'
   call lineout fn , "<TABLE BORDER=4 CELLSPACING=4 CELLPADDING=4>"
   call lineout fn , "<TR>"
 return  ""

closehtml: procedure
 parse arg fn
 call lineout fn , '</TD>'
 call lineout fn ,'</TR>'
 call lineout fn ,'</TABLE>'
 call lineout fn , '<body>'
 call lineout fn , '</html>'
 call lineout fn   -- close file
 return   ""


 -- write out the data associated with each object
 -- a header, and the table definition

 doSection:
 parse arg fn
  call lineout fn , "<h2 id="objName">"objtype objname"</h2>"
  call lineout fn , "<TABLE BORDER=4 CELLSPACING=4 CELLPADDING=4>"
  call lineout fn , "<TR>"
  call lineout fn , startTH(objname)||objname||endTH(objname)
  call lineout fn , "<TH>Differences</thd>"
  -- put out all of the queue managers as a table header
  do iqm=1 to words(qmgrs)
      qm = word(qmgrs,iqm)
       call lineout fn ,"<TH>"qm"</thd>"
   --   diff.iqm = 0  -- reset these
   end
   call lineout fn , '</TR>'
return   ''

 doDiffHeader:
 parse arg fn

  call lineout fn , "<h2 id="objName">"objtype objname"</h2>"
  call lineout fn , "<TABLE BORDER=4 CELLSPACING=4 CELLPADDING=4>"
return   ''


-- Read the file containgin the list of attributes to ignore when doing a compare
-- ** this is a comment
-- *.xx means xx is ignore for all object types - such as ALTTIME
-- Object.xx  so QMGR.QMID ignores this when comparing as they are always differnt
-- QLOCAL.CURDEPTH is another example
DoIgnores:
 do i= 1  while  lines( ignorefile)  -- lines(..) gives 1 if more lines preset
   ignorel = linein( ignorefile)
   parse var ignorel o'.'n .
   if subst(ignorel,1,2) ='**' then iterate
   if (o=''|n='') then  iterate i

   o = strip(o)
   n = strip(n)
   if (o ='*') then ignoreall.n= 1
   else ignore.o.n =1
 end
Return '' ;
