<!---
   need to check if this course is associated with any available bundles.
   if so, tell them.
--->
<CFIF not isDefined("getp") OR  (isDefined("getp") and getp.recordcount EQ 0) >
	<CFINCLUDE template="../datasets/get_student_programs.cfm">
</CFIF>

<CFSET plist=valuelist(getp.key_prog) >

<cfset variables.currentEnrollment = 0>

<cfif FileExists(ExpandPath('#client.custom_path#/config/CourseCatalog_constants.cfm'))>
	<cfinclude template="#client.custom_path#/config/CourseCatalog_constants.cfm">
</cfif>

<CFIF NOT isDefined("cnst_stu_cat_show_cost")>
	<CFSET cnst_stu_cat_show_cost = 1>
</CFIF>

<cfset variables.allowRegister = "true">

<CFQUERY name="qGetColumn" datasource="#db.connect#" timeout="#db.timeout#">
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'retail_pricev'
	AND COLUMN_NAME = 'currency_locale'
</CFQUERY>

<CFIF not isDefined("catalog_presets") and qGetColumn.recordcount NEQ 0>
	<CFINCLUDE template = "../cart/catalog_presets.cfm">
</CFIF>

<CFIF use_shopping_cart EQ 0>
	<CFSET cart_pagedef="signup">
</CFIF>

<cfquery name="qGetStudentInfo" datasource="#db.connect#"  >
	SELECT	key_student
	FROM		student with (nolock)
	WHERE		fkey_contact = #client.contact_key#
</cfquery>

<cfset variables.key_student = qGetStudentInfo.key_student>

<CFQUERY name="sched_info" datasource="#db.connect#" timeout="#db.timeout#">
	select	fkey_class,
				class_date
				,datediff(day,'#DATEFORMAT(NOW(),"mm/dd/yyyy")#',classes.start_date) as date_diff,
				start_time,
				end_time,
				class_sched.fkey_classroom,
				rtrim(topic) as topic,
				rtrim(topic_desc) as topic_desc, start_date, end_date, key_course
	from 		class_sched with (nolock), classes with (nolock) ,course_core_data with (nolock)
	where 	key_sched = #URL.sched# and key_class = fkey_class and fkey_course=key_course
</CFQUERY>

<CFSET variables.keyClass = sched_info.fkey_class>
<CFSET variables.startTime = sched_info.start_time>
<CFSET variables.endTime = sched_info.end_time>

<CFQUERY name="class_info" datasource="#db.connect#" timeout="#db.timeout#">
	select	distinct key_contact,
				rtrim(first_name) as first_name,
				rtrim(last_name) as last_name,
				key_course, classes.max_cost_per_student,isnull(retail_pricev.final_price,0) as final_price,
				rtrim(course_core_data.course_id) as course_id,
				rtrim(course_core_data.course_name) as course_name,
				rtrim(course_core_data.description) as description,
				credits , isnull(credit_type+':','') as credit_type, class_payment_perm, class_stip_perm,class_inv_perm
				,pricingv.member_price ,FINAL_price ,program,key_prog ,yr,isnull(fkey_class_bundle,0) as fkey_class_bundle
				,classes.class_status
	from 		classes
				left outer join contact with (nolock) on
					fkey_contact = key_contact
				left outer join course_core_data with (nolock) on
					fkey_course = key_course

				left outer join retail_pricev with (nolock) on fkey_class=key_class
					and key_course_group is null
					<cfif qGetColumn.recordcount NEQ 0>
					and isnull(currency_locale,'#use_currency_locale#')='#use_currency_locale#'
					</cfif>

				left outer join pricingv with (nolock) on retail_pricev.key_price=pricingv.key_price and pricingv.fkey_currency=retail_pricev.fkey_currency
				<CFIF isDefined("url.prg") and url.prg GT 0>
					AND retail_pricev.key_prog=#url.prg#
				<CFELSE>
					AND retail_pricev.key_prog in (#plist#)
				</CFIF>
				left outer join classes_bundle  with (nolock) on classes_bundle.key_class_bundle=classes.fkey_class_bundle
	where 	key_class = #sched_info.fkey_class# and rtrim(class_status) = 'open'
</CFQUERY>


<CFIF not isdefined("stip_perm_label")>
	<CFSET Stip_perm_label = "@GETMSG(CAL_PermSupervisor)">
</CFIF>

<CFIF not isdefined("payment_perm_label")>
	<CFSET Payment_perm_label = "@GETMSG(CAL_PermPayment)">
</CFIF>

<CFIF not isdefined("inv_perm_label")>
	<CFSET inv_perm_label = "@GETMSG(CAL_PermInventory)">
</CFIF>

<CFSET variables.thisCourse = class_info.key_course>

<CFIF getp.recordcount GT 0>
	<CFSET prog_list=valueList(getp.key_prog)>
<CFELSE>
	<CFSET prog_list= 0>
</CFIF>

<!--- If the program key was sent to the page, use it; otherwise find an eligible program key --->
<cfif isDefined("url.prg")>

	<CFSET variables.prog = URL.prg>
<cfelse>
	<CFSET variables.programList =plist >

	<!--- Determine Enrollment --->
	<CFSET variables.thisEnrollment = 0>

	<CFIF #len(variables.key_student)# GT 0>
	<CFQUERY name="qGetStuEnrollments" datasource="#db.connect#"  timeout="#db.timeout#">
		select	key_enrollment,
					fkey_prog
		from 		stu_enrollment
		where 	fkey_student = (#variables.key_student#) and fkey_prog in (#variables.programList# )
			and fkey_enrollment_status in (2,5,8) order by fkey_enrollment_status
	</CFQUERY>

	<CFIF qGetStuEnrollments.recordCount GT 0>
		<CFIF variables.thisEnrollment EQ 0>
			<CFIF ListFind(variables.programList,qGetStuEnrollments.fkey_prog) GT 0>
				<CFSET variables.thisEnrollment = qGetStuEnrollments.key_enrollment>
				<CFSET variables.thisEnrollmentProgKey = qGetStuEnrollments.fkey_prog>
				<CFSET variables.prog=variables.thisEnrollmentProgKey>

			</CFIF>
		</CFIF>

	</CFIF>

	</Cfif>

	<!---72350. find all related bundles for this course - only if all courses in the bundle are active --->
<CFQUERY name="checkbundles" datasource=#db.connect#>
	select distinct key_course_group,course_group_name,description,bundles_only,p.key_prog,p.program
	<CFIF class_info.fkey_class_bundle GT 0 >
		,key_class_bundle
	<CFELSE>
		,0 as key_class_bundle
	</CFIF>
	from course_group
	<CFIF class_info.fkey_class_bundle GT 0>
		join classes_bundle on classes_bundle.key_class_bundle=#class_info.fkey_class_bundle#
			and classes_bundle.fkey_course_group=course_group.key_course_group
	</CFIF>
	outer apply
	  ( select key_map_step, key_prog, isnull(bundles_only,0) as bundles_only,key_course,program
		from  training_mapV where key_prog in (#plist#) ) p

	where p.key_map_step=course_group.fkey_map_step
	and p.key_course=#sched_info.key_course#
	and key_course_group not in
		(select fkey_course_group from course_group_items with (nolock),course_core_Data with (nolock)
			where course_group_items.fkey_course=course_core_data.key_course and active=0)
</CFQUERY>


<!--- if we can find any program for this course where you dont need to sign up for the whole bundle
	- then we can allow the register button for the individual class
--->
<CFQUERY name="notJustBundles" datasource=#db.connect#>
		select  *
 		from  training_mapV p
		where key_prog in (#plist#)
	and p.key_course=#sched_info.key_course#
	 and  bundles_only =0
</CFQUERY>

<CFSET bundlemsg="">
<CFIF checkbundles.recordCount GT 0>
	<cfset bundledProgs = "">

	<CFSAVECONTENT variable="bundlemsg" >
		<CFOUTPUT>
			<div class="bundleProgs">
				<p>This course is included in the following bundles:</p>
				<ul>
				<CFLOOP query="checkbundles">
					<cfset ajax_url = "../pagebuilder/showpage.cfm?pagedef=dialog&loc=cart&goto=training_signup_bundle&#URLTOKEN#&enr=0&group=#checkbundles.key_course_group#&prgkey=#checkbundles.key_prog#&b_id=#checkbundles.key_class_bundle#&cls=#sched_info.fkey_class#&price=" />


					<cfset bundledProgs = listAppend(bundledProgs, checkbundles.key_prog)>
						<li>
							<span class="glyphicon glyphicon-question-sign"></span><span onclick="showDescription('#ajax_url#')">#checkbundles.course_group_name#
								<BR />[program: #checkbundles.program#]
							</span>

			<!---	<p>#checkbundles.key_course_group# <br>
					 #checkbundles.key_prog#</p> --->
						</li>
					</CFLOOP>
				</ul>
			</div>
		</CFOUTPUT>
	</CFSAVECONTENT>
	<!--- Check if enrolled for particular bundle this course is included in
	<cfset tempBundleCk = listFind(bundledProgs, qGetStuEnrollments.fkey_prog)>
	 --->
</CFIF>

<style>
/* --- blockui modal styling --- */
	div#wider.blockUI.blockMsg.blockPage {
    box-sizing: border-box;
    top: 10%;
    left: 33%;
    margin: 0;
    padding: 4px;
    width: auto;
    /*height: 56vh;*/
    /*height: 534px;*/
    /*overflow-x:hidden;
    overflow-y:scroll;*/
    text-align: center;
    background-color: #fff;
    border: 1px solid #000;
    border-radius: 0.3rem;
    cursor: wait;
	}

	div#event_description p.title {
	  margin: 0;
	  padding: 6px 0 1px 8px;
	  text-align: left;
	  font-size: 150%;
	  font-weight: 600;
	  border-bottom: 2px solid #e0e0e0;
	}

	iframe#event_frame{
	  width: 570px;
	  height: 50vh;
	  overflow: hidden;
	  border: 0;
	}

	a#closeMe {
	  padding: 0 3px 5px 5px;
	  float: right;
	  color: #c8c8c8;
	  font-size: 175%;
	  font-weight: 600;
	}

	a#closeMe:hover {
	  color: #787878;
	}
</style>

<script>
	function showDescription(the_url)
	{
		<CFOUTPUT>
			var ui_html='<div id="event_description"><a href="##" id="closeMe" onclick="$.unblockUI();">X</a><p class="title">Bundle Details</p><iframe src="'+the_url+'" id="event_frame" frameborder="0" scrolling="auto"></iframe></div>';

			$.blockUI.defaults.css = {};

		    jQuery.blockUI(
		    { message: ui_html,
			    onOverlayClick: $.unblockUI,
			    onBlock: function() {
	               $(".blockPage").attr('id',"wider");
	            }
	        }
		    				);
		 </CFOUTPUT>

	}
</script>

	<cfif not isDefineD("variables.thisEnrollment") or variables.thisEnrollment EQ 0>

		<CFIF #len(variables.key_student)# GT 0>
		<cfquery name="qGetEligiblePrograms" datasource="#db.connect#">
			Select	cr.fkey_program
			From 		company_rules cr
						INNER JOIN contact c ON
							c.fkey_company = cr.fkey_company
							AND key_contact = (select fkey_contact from student where key_student = #variables.key_student#)
						<cfif isDefined("use_job_titles") AND use_job_titles eq 1>
							INNER JOIN program_title_map ptm ON
								ptm.fkey_prog = cr.fkey_program
								AND ptm.fkey_title IN (select fkey_title from stu_roles where fkey_student = #variables.key_student#)

						</cfif>
			and allow_prog_part = 1
		</cfquery>
		<CFELSE>
		<cfquery name="qGetEligiblePrograms" datasource="#db.connect#">
			select cr.fkey_program from company_rules cr, company where name = '#default_company#' and
			fkey_company = key_company and allow_prog_part = 1
		</Cfquery>
		</CFIF>

		<cfset variables.prog = 0>

		<cfloop query="qGetEligiblePrograms">
			<cfset variables.thisProgramKey = qGetEligiblePrograms.fkey_program>
			<!--- If an Eligible program is in the program list, enroll student in that program --->
			<cfif ListFind(variables.programList, variables.thisProgramKey) GT 0>
				<cfset variables.prog = variables.thisProgramKey>
				<cfbreak>
			</cfif>
		</cfloop>

		<cfif isDefined("CNST_STU_CAT_show_future_classes_only") and CNST_STU_CAT_show_future_classes_only eq 1>

		</CFIF>
		<cfif ( client.usertype EQ "anonymous" OR variables.prog GT 0) and isDefined("variables.CNST_AUTOENROLL") AND variables.CNST_AUTOENROLL EQ "true"
			AND class_info.class_status EQ "open" >
			<cfset variables.allowRegister = "true">
		<cfelse>
			<cfset variables.allowRegister = "false">
		</cfif>

	<cfelse>
		<cfset variables.currentEnrollment = variables.thisEnrollment>
		<cfset variables.prog = variables.thisEnrollmentProgKey>
	</cfif>
</cfif>

 <CFIF sched_info.date_diff LTE 0>
	<CFSET variables.allowRegister="false">

 </CFIF>

<cfquery name="qGetProgramName" datasource="#db.connect#">
	SELECT	program
	FROM		program_type
	WHERE		key_prog = #variables.prog#
</cfquery>

<cfset variables.programName = qGetProgramName.program>

<CFSET THE_PRICE=#class_info.final_price#>


<!---Check on a discount for this course--->
<CFQUERY name="stuComp" datasource="#db.connect#" timeout="#db.timeout#">
	select 	fkey_company
	from 		contact
	where 	key_contact = #Client.contact_key#
</CFQUERY>
<CFIF #len(variables.key_student)# Gt 0>
	<CFQUERY name="disc" datasource="#db.connect#" timeout="#db.timeout#">
		select 	isnull(discount,0) as discount
		from 		company_rules
		where 	fkey_program = #variables.prog#
				and fkey_company = #stuComp.fkey_company#
	</CFQUERY>


<CFELSE>
	<CFQUERY name="disc" datasource="#db.connect#" timeout="#db.timeout#">
		select 	isnull(discount,0) as discount
		from 		company_rules, company
		where 	fkey_program = #variables.prog#
				and fkey_company = key_company and name = '#default_company#'
	</CFQUERY>

	<CFSET disc.discount=0>
</CFIF>

<CFIF disc.discount GT 1 AND THE_PRICE GT 0>
	<CFSET THE_PRICE = THE_PRICE - disc.discount>
<CFELSEIF disc.discount GT 0>
	<CFSET THE_PRICE = THE_PRICE * (1 - disc.discount)>
</CFIF>
<CFIF THE_PRICE LT 0>
	<CFSET THE_PRICE=0>
</CFIF>

<CFSET THE_PRICE = NumberFormat(THE_PRICE,"9999.99")>

<CFQUERY name="room_info" datasource="#db.connect#" timeout="#db.timeout#">
	select 	rtrim(room) as room,
				rtrim(location) as location,
				rtrim(addr) as addr,
				rtrim(addr2) as addr2,
				rtrim(city) as city,
				rtrim(state) as state,
				rtrim(zip) as zip,
				rtrim(phone) as phone,
				rtrim(directions) as directions,
				rtrim(accomodations) as accomodations,
				rtrim(loc_type) as loc_type
				,case when loc_type='online' then
					case when isnull(addr,'') = '' then '@GETMSG(APP_ONLINE)' else addr end
				  else location end as final_location
	from classrooms
	where key_classroom = #sched_info.fkey_classroom#
</CFQUERY>


<cfoutput>
<div align="center">
	<div class="fineprint" id="training_cal_details">
		<TABLE   width="100%" cellspacing="0" cellpadding="3"  >
			<TR>
				<TD colspan="2"><H1 class="submenu2">@GETMSG(S_CRS_DETAILS) #class_info.course_id#, #TimeFormat(variables.startTime,client.time_format)#,

						#room_info.final_location#

				</H1></TD>
			</TR>
			<TR>
				<TD valign="top"  ><B>@GETMSG(S_CRS_COURSE):</B></TD>
				<TD>#class_info.course_name#</TD>
			</TR>
			<TR>
				<TD valign="top"><B>@GETMSG(APP_Description):</B></TD>
				<TD  >#class_info.description#</TD>
			</TR>
			<TR>
				<TD valign="top"><B>@GETMSG(TRN_Credits):</B></TD>
				<TD>#class_info.credits#</TD>
			</TR>
			<cfif cnst_stu_cat_show_cost eq 1>
				<TR>
					<TD valign="top"><B>@GETMSG(S_CRS_Cost):</B></TD>
					<TD>
					<cfif qGetColumn.recordcount NEQ 0>
						<CFSET mylocale=SetLocale(use_currency_locale) >
						#lsCurrencyFormat(THE_PRICE,use_currency_format)#
						<CFIF class_info.member_price NEQ THE_PRICE and class_info.member_price GTE 0.0>
							/ <span class="cartMemberLabel">@GETMSG(CART_Member)</span><span class="cartMemberPrice"> #lsCurrencyFormat(class_info.MEMBER_PRICE,use_currency_format)#</span>
						</CFIF>
					<cfelse>
						#NumberFormat(THE_PRICE,"$9999.99")#
					</cfif>
					</TD>
				</TR>
			</cfif>
			<TR>
				<TD valign="top"><B>@GETMSG(APP_Instructors):</B></TD>
				<TD>
					<CFQUERY name="instrs" datasource="#db.connect#" timeout="#db.timeout#">
						select	rtrim(first_name) as first_name,
									rtrim(last_name) as last_name
						from 		class_instructors,
									contact
						where 	fkey_contact = key_contact
									and fkey_class = #variables.keyClass#
					</CFQUERY>

					<CFLOOP query="instrs">
						#instrs.first_name# #instrs.last_name#<BR>
					</CFLOOP>

					<CFIF instrs.recordCount EQ 0>
						<i>@GETMSG(APP_NotListed)</i>
					</CFIF>
				</TD>
			</TR>
			<TR>
				<TD valign="top"><B>@GETMSG(APP_Dates):</B></TD>
				<TD>#DateFormat(sched_info.start_date,"short")#<CFIF #DateFormat(sched_info.end_date,"short")# NEQ #DateFormat(sched_info.start_date,"short")#> - #DateFormat(sched_info.end_date,client.date_format)#</CFIF></TD>
			</TR>
			<TR>
				<TD valign="top"><B>@GETMSG(APP_Room):</B></TD>
				<TD>#room_info.room#&nbsp;</TD>
			</TR>
			<TR>
				<TD valign="top"><B>@GETMSG(APP_LOCATION):</B></TD>
				<TD   >
					#room_info.final_location#

					&nbsp;
				</TD>
			</TR>
			<cfif room_info.loc_type neq "online" and trim(room_info.addr) NEQ "">
				<TR>
					<TD valign="top"><B>@GETMSG(S_PROF_ADDRESS):</B></TD>
					<TD>
						#room_info.addr#<br/>
						<cfif room_info.addr2 NEQ "">#room_info.addr2#<br/></cfif>
						#room_info.city# #room_info.state# #room_info.zip#
					</TD>
				</TR>
			</cfif>
			<cfif trim(room_info.phone) NEQ "">
				<TR>
					<TD valign="top"><B>@GETMSG(APP_Phone):</B></TD>
					<TD>#room_info.phone#&nbsp;</TD>
				</TR>
			</cfif>
			<cfif trim(room_info.directions) NEQ "" AND compareNoCase(room_info.loc_type,"Physical") EQ 0>
				<TR>
					<TD valign="top"><B>@GETMSG(APP_Directions):</B></TD>
					<TD >

						#room_info.directions#&nbsp;

					</TD>
				</TR>
			</cfif>
			<cfif trim(room_info.accomodations) NEQ "">
				<TR>
					<TD valign="top"><B>@GETMSG(APP_Accomodations):</B></TD>
					<TD width="80%">#room_info.accomodations#&nbsp;</TD>
				</TR>
			</cfif>
			<CFIF Len(sched_info.topic) GT 0>
				<TR>
					<TD valign="top"><B>@GETMSG(APP_Topic):</B></TD>
					<TD width="80%">
						#sched_info.topic#
					</TD>
				</TR>
			</CFIF>
			<CFIF Len(sched_info.topic_desc) GT 0>
				<TR>
					<TD valign="top"><B>@GETMSG(APP_Details):</B></TD>
					<TD width="80%">
						#sched_info.topic_desc#&nbsp;
					</TD>
				</TR>
			</CFIF>

			<CFIF class_info.class_stip_perm EQ 1>
				<TR>
					<TD valign="top" ><B>@GETMSG(APP_Required):</b></td>
					<TD ><font class="mainalt">#stip_perm_label#</font></TD>
				</TR>
			</CFIF>

			<CFIF class_info.class_inv_perm EQ 1>
				<TR>
					<TD valign="top" ><B>@GETMSG(APP_Required):</b></td>
					<TD ><font class="mainalt">#inv_perm_label#</font></TD>
				</TR>
			</CFIF>

			<CFIF class_info.class_payment_perm EQ 1>
				<TR>
					<TD valign="top" ><B>@GETMSG(APP_Required):</b></td>
					<TD ><font class="mainalt">#payment_perm_label#</font></TD>

				</TR>
			</CFIF>

			<CFIF bundlemsg NEQ "">

				<TR><TD colspan=2><CFOUTPUT>#bundlemsg#</CFOUTPUT>
				<BR>
				<cfif variables.allowRegister eq "true" AND notJustBundles.recordcount EQ 0>
						<p class="helpText">* @GETMSG(CAL_NOREG_BUNDLEONLY)</p>
				</CFIF>

				</td></tr>

			</CFIF>
			<TR>
				<td></td>
				<TD id="tdCalClassRegister" align="right" style="width:100%">
					<BR>
					<cfif variables.allowRegister eq "true" >
						<CFIF notJustBundles.recordcount GT 0 >
							<cfset registerURI = "../pageBuilder/showPage.cfm?reg_perm=1&pagedef=#cart_pagedef#&goto=course_signup&"
									 & URLTOKEN
									 & "&enr=" & variables.currentEnrollment
									 & "&crs=" & variables.thisCourse
									 & "&id=" & Trim(Replace(class_info.course_id,"##","%23","ALL"))
									 & "&prg=" & Trim(Replace(notJustBundles.program,"##","%23","ALL"))
									 & "&prgkey=" & notjustbundles.key_prog
									 & "&price=" & TRIM(THE_PRICE)>

								<CFSET registeruri=registeruri & "&cls=" & variables.keyClass>
 								<button type="button" class="buyBtn btn btn-success btn-sm" href="javascript:void();" onclick= "addSelection('#registerURI#');">
									<span class="glyphicon glyphicon-plus-sign" aria-hidden="true"></span> #register_name#
								</button>

						<CFELSE>
						<!--- @GETMSG(CAL_NOREG_BUNDLEONLY)  --->
						</CFIF>
					<cfelse>

						<font class="mainalt">
							@GETMSG(REG_ToRegYouMustEnroll1) <b>#Trim(variables.programName)#</b> @GETMSG(REG_ToRegYouMustEnroll2)
						</font>
						&nbsp;&nbsp;

					</cfif>
					<!--- no more popup, per Case 40773 --->
					<cfif cgi.http_referer CONTAINS "classcalendar">

						<button type="button" class="btn btn-warning" id="cartBackBtn" onclick="javascript:window.history.go(-1); return false;">@GETMSG(CAL_BackToCal)</button>

						<!---<INPUT type="button" class="btn" value="@GETMSG(CAL_BackToCal)" onClick="location.href='<CFOUTPUT>#cgi.http_referer#</CFOUTPUT>'">--->
					<cfelse><!--- we aren't always coming from the calendar, per Case 40166 --->

						<button type="button" class="btn btn-warning" id="cartBackBtn" onclick="javascript:window.history.go(-1); return false;">@GETMSG(BTN_BACK)</button>

						<!---<INPUT type="button" class="btn" value="@GETMSG(BTN_Back)" onClick="location.href='<CFOUTPUT>#cgi.http_referer#</CFOUTPUT>'">--->
					</cfif>
					<BR><BR>
				</TD>
			</TR>
		</table>
				<CFIF sched_info.date_diff LTE 0>
					<CF_Rendermsg message_type="error" Title="">
					You are not able to register for a class that is in the past.
					</CF_Rendermsg>
				</CFIF>
	</div>

<CFQUERY name="others" datasource="#db.connect#" timeout="#db.timeout#">
	select	rtrim(first_name) as first_name,
				rtrim(last_name) as last_name,
				class_date,
				start_time,
				end_time,
				rtrim(room) as room,
				rtrim(classrooms.location) as location,
				isnull(rtrim(classrooms.addr),'') as addr,
				classrooms.loc_type,classes.class_status,

				isnull(rtrim(timezone_GMT), '') as timezone_GMT
				,case when classrooms.loc_type='online' then
					case when isnull(classrooms.addr,'') = '' then '@GETMSG(APP_ONLINE)' else classrooms.addr end
				  else classrooms.location end as final_location
	from 		class_sched with (nolock)
				left outer join classes with (nolock) on fkey_class = key_class
				left outer join timezone with (nolock) on fkey_timezone = key_timezone
				left outer join contact with (nolock) on fkey_contact = key_contact
				left outer join classrooms with (nolock) on class_sched.fkey_classroom = key_classroom
	where 	key_class = #variables.keyClass#

	order by class_date, start_time
</CFQUERY>

<cfif others.recordcount GT 0>
	<TABLE   id="training_cal_details_sessions" cellspacing="0" cellpadding="3" border="0">
		<TR>
			<TD ><BR>
				<B>@GETMSG(CAL_ClassDatesTimes):</B><BR>
				<cfif Len(#others.timezone_GMT#) GT 0>
					<cfoutput>@GETMSG(REG_TimeZone): #others.timezone_GMT#</cfoutput>
				</cfif>

	<cfoutput>

				<Z:TABLE cols="@GETMSG(APP_Instructors), @GETMSG(APP_DateTime), @GETMSG(APP_RoomLoc)<CFIF isDefined('register_cols') AND findnocase('current-max', register_cols) GT 0>, @GETMSG(APP_NumMax) </cfif>"  cellspacing="0" cellpadding="1" border="0" class="zlist table<cfif IsDefined("tableClass") and len(tableClass)> #tableClass#</cfif>"  format="table"  >

 						<CFSET LOOPCLS = "subalt1">
						<CFLOOP query="others">
							<row>
								<data class="#LOOPCLS#" width="100">
									<CFQUERY name="instr" datasource="#db.connect#" timeout=#db.timeout#>
										select	rtrim(first_name) as first_name,
													rtrim(last_name) as last_name
										from 		class_instructors,
													contact
										where 	fkey_contact = key_contact
													and fkey_class = #variables.keyClass#
									</CFQUERY>

									<CFLOOP query="instr">
										#instr.first_name# #instr.last_name#<BR>
									</CFLOOP>

									<CFIF instr.recordCount EQ 0>
										&nbsp;
									</CFIF>
								</data>
								<data class="#LOOPCLS#" width="160">
									#DateFormat(others.class_date,client.date_format)#, #TimeFormat(others.start_time,client.time_format)# - #TimeFormat(others.end_time,client.time_format)#
								</data>
								<data class="#LOOPCLS#" width="270">
									#others.room#
									<CFIF Len(#others.room#) GT 0 AND Len(#others.location#) GT 0>
										 @GETMSG(APP_AT)
									</CFIF>

										#others.final_location#

									&nbsp;
								</data>

						<CFIF isDefined("register_cols") AND findnocase("current-max", register_cols) GT 0>

				                 <data class="#LOOPCLS#" width="40">
									<CFQUERY name="cap" datasource="#db.connect#"  timeout="#db.timeout#">
										select	class_capacity as capacity
										from 		classes
										where 	key_class = #variables.keyClass#
									</CFQUERY>
									<CFSET MAX_LEVEL = cap.capacity>
									<CFQUERY name="reg" datasource="#db.connect#"  timeout="#db.timeout#">
										select 	count(key_reg) as num_reg
										from 		stu_registration,
													course_status_type
										where 	fkey_class = #variables.keyClass#
													and fkey_course_status = key_course_status_type
													and course_open = 1
									</CFQUERY>
									<CFSET CURR_LEVEL = reg.num_reg>

								   <cfif CURR_LEVEL GTE MAX_LEVEL>
									   <strong><font color="red">
										   Class Full
									   </font></strong>
                        					<cfelse>


								 <cfoutput>#CURR_LEVEL# / #MAX_LEVEL#</cfoutput>

                  					</CFIF>

							</data>
							</CFIF>
				</row>
							<CFIF NOT CompareNoCase(LOOPCLS,"subalt1")>
								<CFSET LOOPCLS = "subalt2">
							<CFELSE>
								<CFSET LOOPCLS = "subalt1">
							</CFIF>
						</CFLOOP>
					</Z:TABLE>

			</TD>
		</TR>
	</TABLE>
	</cfoutput>
</cfif>
</div>
</cfoutput>
