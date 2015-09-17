create or replace PROCEDURE NEWS_TOEMAIL AS 
char_NAME varchar2(15 char) := '*|NAME|*'; -- Имя-Отчество clients
char_DEAR varchar2(15 char) := '*|DEAR|*'; -- обращение к клиенту УВАЖАЕМЫЙ или УВАЖАЕМАЯ
char_EMAILTO varchar2(15 char) := '*|EMAILTO|*';
char_CARDID varchar2(15 char) := '*|CARDID|*';
char_TEXTINPUT varchar2(15) := '*|TEXTINPUT|*';

-- Переменная для хранения текста для вставки в лог файл 
TextLog varchar2(2048 char);
CountRec integer; -- переменная для подсчёта количества сформир записей в таблице
DateStart date; -- дата начала выполнения процедуры
DateEnd date; -- дата окончания выполения процедуры
resmsg clob; -- переменная для формирования текста сообщения персонально каждому клиенту в зависомости от события или новости + форматирования этой мессадж

    -- курсор с записями из таблиц CONTREXT для формирования адресатов для отправки по электронной почте
    CURSOR cur_address is
    select contrext.surname, contrext.firstname, contrext.secondname, contrext.sex, contrext.email, contrext.idcardcode 
    from contrext
    where
        CONTREXT.EMAIL is not null and
        (CONTREXT.OUTFLAGS = 1 or CONTREXT.OUTFLAGS = 4 or CONTREXT.OUTFLAGS = 5 or CONTREXT.OUTFLAGS = 7);
    val_address cur_address%ROWTYPE;
    
    -- Курсор новостей
    CURSOR cur_news is
    select news.NEWSCODE, news.BEGINDATE, news.ENDDATE, news.OUTFLAGEMAIL, 
           news.NEWSSUBJECTEMAIL, news.EMAILTEXT, email_template.htmltext
    from rcd.news
    left join email_template on email_template.ID = news.TEMPLATE
    where
      NEWS.OUTFLAGEMAIL = 0 and 
      news.NEWSTYPE = 0 and
      sysdate >= NEWS.BEGINDATE and 
      sysdate <= NEWS.ENDDATE;
    val_news cur_news%ROWTYPE;
    
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
BEGIN -- General body

DateStart := sysdate;
CountRec := 0;
 
-- Цикл формирования сообщений новостей для клиентов пожелавших их получать
    for val_news in cur_news
    loop
      for val_address in cur_address
      loop
        -- Здесь вставить обработку тэгов при необходимости вставки ИМЯ_ОТЧЕСТВО клиента в текст сообщения новости
        -- Добавлена обработка тэгов *|NAME|*
        val_news.emailtext := replace(val_news.emailtext, chr(10), '<br>');
        resmsg := replace(val_news.htmltext, char_TEXTINPUT, val_news.emailtext);
        resmsg := REPLACE(resmsg, char_NAME, val_address.firstname||' '||val_address.secondname);        
        if val_address.sex = 'мужской'
            then resmsg := REPLACE(resmsg, char_DEAR, 'Уважаемый');
        elsif val_address.sex = 'женский'
            then resmsg := REPLACE(resmsg, char_DEAR, 'Уважаемая');
        else resmsg := REPLACE(resmsg, char_DEAR, 'Уважаемый(ая)');                                
        end if;
        resmsg := REPLACE(resmsg, char_EMAILTO, val_address.email);
        resmsg := REPLACE(resmsg, char_CARDID, val_address.idcardcode);
                
        -- Добавление записи с новостью в таблицу сообщений
        insert into SENDEMAIL (SENDEMAIL.IDCARDCODE, SENDEMAIL.EMAIL, SENDEMAIL.SENDFLAG, SENDEMAIL.TEXTEMAIL, SENDEMAIL.SENDSUBJECTEMAIL, SENDEMAIL.TODATE)
            values (val_address.idcardcode, val_address.email, 0, resmsg, val_news.newssubjectemail, val_news.enddate+1);
        commit;
        CountRec := CountRec + 1; --Увеличиваю счётчик записей
      end loop;
      -- выставляю флаг формирования сообщений новостей
      update NEWS set OUTFLAGEMAIL = 1 
      where NEWS.NEWSCODE = val_news.NEWSCODE;
      commit;
    end loop; --news 

    TextLog := 'Процедура NEWS_TOEMAIL выполнена. Добавлено записей в таблицу: ' || to_char(CountRec);
    insert into LOGJOBS (LOGJOBS.COUNTREC, LOGJOBS.DATESTARTJOB, LOGJOBS.DATEENDJOB, LOGJOBS.FLAGERRORJOB, LOGJOBS.NAMEJOB, LOGJOBS.TEXTERRORJOB)
             values (CountRec, DateStart, sysdate, 0, 'NEWS_TOEMAIL', TextLog);
    commit;


EXCEPTION WHEN others THEN 

    TextLog := 'Ошибка: ' || sqlerrm;
   insert into LOGJOBS (LOGJOBS.COUNTREC, LOGJOBS.DATESTARTJOB, LOGJOBS.DATEENDJOB, LOGJOBS.FLAGERRORJOB, LOGJOBS.NAMEJOB, LOGJOBS.TEXTERRORJOB)
             values (CountRec, DateStart, sysdate, 1, 'NEWS_TOEMAIL', TextLog);
   commit;
   --raise_application_error(-20000, 'Ошибка: ' || sqlerrm);
   
END NEWS_TOEMAIL;
