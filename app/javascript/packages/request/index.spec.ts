import sinon from 'sinon';
import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import { request } from '.';

describe('request', () => {
  const sandbox = useSandbox();

  it('includes the CSRF token by default', async () => {
    const csrf = 'TYsqyyQ66Y';
    const mockGetCSRF = () => csrf;

    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('X-CSRF-Token')).to.equal(csrf);

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      csrf: mockGetCSRF,
    });

    expect(window.fetch).to.have.been.calledOnce();
  });

  it('works even if the CSRF token is not found on the page', async () => {
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      ),
    );

    await request('https://example.com', {
      csrf: () => undefined,
    });
  });

  it('does not try to send a csrf when csrf is false', async () => {
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('X-CSRF-Token')).to.be.null();

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      csrf: false,
    });
  });

  it('prefers the json prop if both json and body props are provided', async () => {
    const preferredData = { prefered: 'data' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: preferredData,
      body: JSON.stringify({ bad: 'data' }),
    });
  });

  it('works with the native body prop', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      body: JSON.stringify(preferredData),
    });
  });

  it('includes additional headers supplied in options', async () => {
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('Some-Fancy')).to.equal('Header');

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      headers: {
        'Some-Fancy': 'Header',
      },
    });
  });

  it('skips json serialization when json is a boolean', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: true,
      body: JSON.stringify(preferredData),
    });
  });

  it('converts a POJO to a JSON string with supplied via the json property', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(JSON.stringify({}), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: preferredData,
    });
  });

  context('with read=false option', () => {
    it('returns the raw response', async () => {
      sandbox.stub(window, 'fetch').resolves(new Response(JSON.stringify({})));
      const response = await request('https://example.com', { read: false });
      expect(response.status).to.equal(200);
    });
  });

  context('with unsuccessful response', () => {
    beforeEach(() => {
      sandbox.stub(window, 'fetch').resolves(new Response(JSON.stringify({}), { status: 400 }));
    });

    it('throws an error', async () => {
      await request('https://example.com', { read: false })
        .then(() => {
          throw new Error('Unexpected promise resolution');
        })
        .catch((error) => {
          expect(error).to.exist();
        });
    });

    context('with read=false option', () => {
      it('returns the raw response', async () => {
        const response = await request('https://example.com', { read: false });
        expect(response.status).to.equal(400);
      });
    });
  });

  context('with response including csrf token', () => {
    beforeEach(() => {
      sandbox.stub(window, 'fetch').callsFake(() =>
        Promise.resolve(
          new Response(JSON.stringify({}), {
            status: 200,
            headers: [['X-CSRF-Token', 'new-token']],
          }),
        ),
      );
    });

    it('does nothing, gracefully', async () => {
      await request('https://example.com', {});
    });

    context('with global csrf token', () => {
      beforeEach(() => {
        document.head.innerHTML += `
          <meta name="csrf-token" content="token" />
          <meta name="csrf-param" content="authenticity_token" />
        `;
      });

      it('replaces global csrf token with the response token', async () => {
        await request('https://example.com', {});

        const metaToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')!;
        expect(metaToken.content).to.equal('new-token');
      });

      it('uses response token for next request', async () => {
        await request('https://example.com', {});
        (window.fetch as SinonStub).resetHistory();
        await request('https://example.com', {});
        expect(window.fetch).to.have.been.calledWith(
          sinon.match.string,
          sinon.match((init) => init!.headers!.get('x-csrf-token') === 'new-token'),
        );
      });

      context('with form csrf token', () => {
        beforeEach(() => {
          document.body.innerHTML += `
            <form><input name="authenticity_token" value="token"></form>
            <form><input name="authenticity_token" value="token"></form>
          `;
        });

        it('replaces form tokens with the response token', async () => {
          await request('https://example.com', {});

          const inputs = document.querySelectorAll('input');
          expect(inputs).to.have.lengthOf(2);
          expect(Array.from(inputs).map((input) => input.value)).to.deep.equal([
            'new-token',
            'new-token',
          ]);
        });
      });
    });
  });
});
