#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "Judy.h"

typedef
struct {
  Pvoid_t judy;
  char  * buf; 
  int     buf_size; 
  int     num_keys;
} judySL;

void
init_buf(judySL * this, const char * key)
{
  int sl = strlen(key);

  if (sl >= this->buf_size) {
    this->buf_size = sl;
    this->buf = (char *)realloc(this->buf, sizeof(char) * (this->buf_size+1));
    if (this->buf == NULL) {
      // XXX die
    }
    this->buf[sl] = '\0';
  }
  strncpy(this->buf, key, sl);
  this->buf[sl] = '\0';

  return;
}

void
dec_values(judySL * this) {
  Word_t * pvalue;

  init_buf(this, "");

  JSLF(pvalue, this->judy, this->buf);
  while (pvalue != NULL) {
    SvREFCNT_dec((SV *)*pvalue);
    JSLN(pvalue, this->judy, this->buf);
  }

  return;
}

MODULE = Tie::Judy		PACKAGE = Tie::Judy		

judySL *
judy_new_judySL()
	CODE:
		judySL * this    = malloc(sizeof(judySL));
		this->judy       = (Pvoid_t) NULL;
		this->buf_size   = 0;
		this->buf        = (char *)  NULL;
		this->num_keys   = 0;
		RETVAL = this;
	OUTPUT:
		RETVAL

void
judy_free_judySL(this)
		judySL * this
	CODE:
		dec_values(this);
		free(this->buf);
		free(this->judy);
		free(this);
		XSRETURN_EMPTY;

SV *
judy_JSLG(this, key)
		judySL     * this
		const char * key
	PREINIT:
		Word_t     * pvalue;
	CODE:
		init_buf(this, key);

		JSLG(pvalue, this->judy, this->buf);
		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		}

		RETVAL = newSVsv((SV *)*pvalue);
	OUTPUT:
		RETVAL

void
judy_JSLI(this, key, value)
		judySL     * this
		const char * key
		SV         * value
	PREINIT:
		Word_t     * pvalue;
	CODE:
		init_buf(this, key);

		JSLI(pvalue, this->judy, this->buf);
		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		}
		SvREFCNT_inc(value);

		if (*pvalue == 0) {
		  this->num_keys++;
		}

		*pvalue = (Word_t)value;

		XSRETURN_EMPTY;

SV *
judy_JSLD(this, key)
		judySL * this
		char   * key
	PREINIT:
		int      rc;
		Word_t * pvalue;
		SV     * value;
	CODE:
		init_buf(this, key);

		JSLG(pvalue, this->judy, this->buf);
		if (pvalue != NULL) {
		  value = (SV *)*pvalue;
		  this->num_keys--;
		}

		JSLD(rc, this->judy, this->buf);

		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		} else {
		  RETVAL = (SV *)value;
		}
	OUTPUT:
		RETVAL

void
judy_JSLFA(this)
		judySL * this
	PREINIT:
		int      rc;
	CODE:
		dec_values(this);

		JSLFA(rc, this->judy);

		this->num_keys = 0;
		this->judy     = (Pvoid_t) NULL;

		free(this->buf);
		this->buf      = (char *) NULL;
		this->buf_size = 0;

		XSRETURN_EMPTY;

char *
judy_JSLF(this)
		judySL * this
	PREINIT:
		Word_t * pvalue;
	CODE:
		init_buf(this, "");

		JSLF(pvalue, this->judy, this->buf);
		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		}

		RETVAL = this->buf;
	OUTPUT:
		RETVAL

char *
judy_JSLN(this)
		judySL     * this
	PREINIT:
		Word_t     * pvalue;
	CODE:
		JSLN(pvalue, this->judy, this->buf);
		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		}

		RETVAL = this->buf;
	OUTPUT:
		RETVAL

int
judy_count(this)
		judySL * this
	CODE:
		RETVAL = this->num_keys;
	OUTPUT:
		RETVAL
