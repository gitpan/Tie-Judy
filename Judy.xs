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
init_buf(judySL * this, const char * key, int keyLen)
{
  if (! keyLen) {
    keyLen = strlen(key);
  }

  if (keyLen >= this->buf_size) {
    this->buf_size = keyLen;
    this->buf = (char *)realloc(this->buf, sizeof(char) * (this->buf_size+1));
    if (this->buf == NULL) {
      croak("out of memory trying to allocate %d bytes", this->buf_size + 1);
    }
    this->buf[keyLen] = '\0';
  }
  strncpy(this->buf, key, keyLen);
  this->buf[keyLen] = '\0';

  return;
}

void
dec_values(judySL * this) {
  Word_t * pvalue;

  init_buf(this, "", 0);

  JSLF(pvalue, this->judy, this->buf);
  while (pvalue != NULL) {
    SvREFCNT_dec((SV *)*pvalue);
    JSLN(pvalue, this->judy, this->buf);
  }

  return;
}

SV *
_judy_JSLG(judySL * this, SV * sv) {
  Word_t * pvalue;
  char   * key;
  STRLEN   keyLen;

  key = (char *)SvPV(sv, keyLen);
  init_buf(this, key, keyLen);
  JSLG(pvalue, this->judy, this->buf);
  if (pvalue == NULL) {
    return &PL_sv_undef;
  } else {
    return sv_2mortal(newSVsv((SV *)*pvalue));
  }
}

void
_judy_JSLI(judySL * this, char * key, I32 keyLen, SV * value) {
  Word_t * pvalue;
  init_buf(this, key, keyLen);
  JSLI(pvalue, this->judy, this->buf);
  if (pvalue != NULL) {
    SvREFCNT_inc(value);
    if (*pvalue == 0) {
      this->num_keys++;
    }
    *pvalue = (Word_t)value;
  }
}

SV *
_judy_JSLD(judySL * this, SV * sv) {
  Word_t * pvalue;
  char   * key;
  STRLEN   pvLen;
  int	   rc;
  SV     * ret;

  key = SvPV(sv, pvLen);
  init_buf(this, key, pvLen);
  JSLG(pvalue, this->judy, this->buf);
  if (pvalue == NULL) {
    ret = &PL_sv_undef;
  } else {
    ret = sv_2mortal(newSVsv((SV *)*pvalue));
    this->num_keys--;
  }

  JSLD(rc, this->judy, this->buf);
  return ret;
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
		init_buf(this, key, 0);

		JSLG(pvalue, this->judy, this->buf);
		if (pvalue == NULL) {
		  XSRETURN_EMPTY;
		}

		RETVAL = newSVsv((SV *)*pvalue);
	OUTPUT:
		RETVAL

void
judy_JSLG_multi(this, ...)
		judySL * this
	PREINIT:
		int      i, j, len, elems;
		STRLEN   n_a;
		SV     * sv, ** svp;
		AV     * av;
	PPCODE:
		elems = 0;
		for (i = 1; i < items; i++) {
		  sv = ST(i);
		  if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
		    av = (AV *) SvRV(sv);
		    len = av_len(av);
		
		    for (j = 0; j <= len; j++) {
		      svp = av_fetch(av, j, 0);
		      if (svp) {
		        XPUSHs(_judy_JSLG(this, *svp));
		        elems++;
		      }
		    }
		  } else {
		    XPUSHs(_judy_JSLG(this, sv));
		    elems++;
		  }
		}
		XSRETURN(elems);

void
judy_JSLI(this, key, value)
		judySL     * this
		const char * key
		SV         * value
	PREINIT:
		Word_t     * pvalue;
	CODE:
		init_buf(this, key, 0);

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

void
judy_JSLI_multi(this, ...)
		judySL * this
	PREINIT:
		int      i, j, len;
		char   * key;
		I32      keyLen;
		SV     * sv, * rv, ** svp, ** valp;
		HV     * hv;
		AV     * av;
		STRLEN   pvLen;
	CODE:
		for (i = 1; i < items; i+=2) {
		  sv = ST(i);
		  if (SvROK(sv)) {
		    rv = SvRV(sv);
		    if (SvTYPE(rv) == SVt_PVAV) {
		      av = (AV *)rv;
		      len = av_len(av);

		      for (j = 0; j < len; j+=2) {
			svp = av_fetch(av, j, 0);
			valp = av_fetch(av, j + 1, 0);

			if (svp && valp) {
			  key = SvPV(*svp, pvLen);

			  _judy_JSLI(this, key, pvLen, *valp);
			}
		      }
		      i--;
		    } else if (SvTYPE(rv) == SVt_PVHV) {
		      hv = (HV *)rv;
		      len = hv_iterinit(hv);
		      for (j = 0; j < len; j++) {
			sv = hv_iternextsv(hv, &key, &keyLen);
			_judy_JSLI(this, key, keyLen, sv);
		      }
		      i--;
		    } else {
		      key = SvPV(sv, pvLen);
		      _judy_JSLI(this, key, pvLen, ST(i + 1));
		    }
		  } else if (i < items - 1) {
		    key = SvPV(sv, pvLen);
		    _judy_JSLI(this, key, pvLen, ST(i + 1));
		  } else {
		    croak("No value for key '%s'\n", SvPV(sv, pvLen));
		  }
		}
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
		init_buf(this, key, 0);

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
judy_JSLD_multi(this, ...)
		judySL * this
	PREINIT:
		int      i, j, len, elems;
		char   * key;
		SV     * sv, ** svp;
		AV     * av;
		STRLEN   pvLen;
	PPCODE:
		elems = 0;
		for (i = 1; i < items; i++) {
		  sv = ST(i);
		  if (SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVAV) {
		    av = (AV *) SvRV(sv);
		    len = av_len(av);
		
		    for (j = 0; j <= len; j++) {
		      svp = av_fetch(av, j, 0);
		      if (svp) {
		        XPUSHs(_judy_JSLD(this, *svp));
		        elems++;
		      }
		    }

		  } else {
		    XPUSHs(_judy_JSLD(this, sv));
		    elems++;
		  }
		}
		XSRETURN(elems);

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
		init_buf(this, "", 0);

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
